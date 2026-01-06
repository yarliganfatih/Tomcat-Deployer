#!/bin/bash

# Deployer Information
deployer_name="Tomcat Deployer"
deployer_version="0.1.2"

# Help Information
_help() {
cat << EOF 
Transfer your changes from your local to remote with a single command.

Setup: ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa

Usage: sh tomcat_deployer.sh [operation] [options] [<goal(s)>] [<phase(s)>]

Operations:
deploy                                       Deploy your java application with your changes on your local.

General options:
-h, -help,           --help                  Display help information.
-v, -version,        --version               Display $deployer_name version.
-V, -verbose,        --verbose               Run script in verbose mode. Will print out each step of execution.
-X, -xtrace,         --xtrace                Run script in xtrace mode. Will print out each step of execution.
-f, -force           --force                 Auto reply as 'Yes' in all question.

Required options for operaions:
-c, -config-file,    --config-file <path>    Local path of config properties profile file.
-u, -remote-user,    --remote-user <user>    Remote server user name.
-i, -remote-ip,      --remote-ip <ip>        Remote server IP address.
-p, -remote-port,    --remote-port <port>    Remote server SSH port. Default is 22.
-r, -remote-path,    --remote-path <path>    Remote server path (Tomcat path) to deploy.
-l, -local-path,     --local-path <path>     Local path of your project.
-n, -package-name,   --package-name <name>   Package name to deploy.
EOF
}

# Default Values
declare -A CONFIG
CONFIG[remote_user]=""
CONFIG[remote_ip]=""
CONFIG[remote_port]="22"
CONFIG[remote_path]="/usr/share/tomcat"
CONFIG[local_path]="./"
CONFIG[package_name]=""

# Load from .properties file
load_config () {
  config_file=$1
  if [[ -f $config_file ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      key="${key//$'\r'/}"
      value="${value//$'\r'/}"
      key="${key## }"; key="${key%% }"
      value="${value## }"; value="${value%% }"
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
      value="${value%%#*}"
      value="${value## }"; value="${value%% }"
      CONFIG["$key"]="$value"
    done < "$config_file"
  else
    echo "[ ERROR ] Config file '$config_file' not found."
    operation_result="Stopped"
    exit 1
  fi
}

options=$(getopt -l "help,version,verbose,xtrace,force,config-file:,remote-user:,remote-ip:,remote-port:,remote-path:,local-path:,package-name:" -o "hvVXfc:u:i:p:r:l:n:" -a -- "$@")
eval set -- "$options"
while true; do
  case "$1" in
  -h|--help)
    _help
    exit 0 ;;
  -v|--version)
    echo $deployer_version
    exit 0 ;;
  -V|--verbose)
    set -v ;;
  -X|--xtrace)
    set -x ;;
  -f|--force)
    CONFIG[is_backup]="Yes"
    CONFIG[is_build]="Yes"
    CONFIG[is_overwrite]="Yes"
    CONFIG[is_rollback]="Yes"
    CONFIG[is_restart]="Yes";;
  -c|--config-file)
    load_config "$2";;
  -u|--remote-user)
    CONFIG[remote_user]="$2";;
  -i|--remote-ip)
    CONFIG[remote_ip]="$2";;
  -p|--remote-port)
    CONFIG[remote_port]="$2";;
  -r|--remote-path)
    CONFIG[remote_path]="$2";;
  -l|--local-path)
    CONFIG[local_path]="$2";;
  -n|--package-name)
    CONFIG[package_name]="$2";;
  --)
    shift
    break;;
  esac
shift
done

# Arguments
operation_mode="$1"
operation_result="Success"
operation_date=$(date +"%Y_%m_%d__%H_%M")

if [[ ${operation_mode^^} == "ROLLBACK" ]]; then
  selected_backup="$2"
fi

# Global Variables
skip_ssh_errors=1
local_branch="main"
changed_list=()
deleted_list=()
to_update_list=()
remote_conn="${CONFIG[remote_user]}@${CONFIG[remote_ip]}"
remote_backup_path="${CONFIG[remote_path]}/temp/backups/${CONFIG[package_name]}"
remote_history_path="${CONFIG[remote_path]}/temp/deploy_history/${CONFIG[package_name]}"
remote_package_path="${CONFIG[remote_path]}/webapps/${CONFIG[package_name]}"

####################################################################################################

deploy_package () {
  deleted_list=("${CONFIG[package_name]}.war")
  changed_list=("${CONFIG[package_name]}.war")
  to_update_list=()

  # Backup current package on remote server
  backup

  # Check package for up-to-date
  build_if_required

  # Check change history on remote server
  check_history
  if [[ $to_update_list -ne 0 ]]; then
    echo "[ WARN ] Deploy operation may be cause conflicts."
    operation_result="Stopped"
    finish 1
  fi

  # Remove current package on remote server
  echo "[ INFO ] Removing current ${CONFIG[package_name]} package on server."
  _ssh "rm -rf $remote_package_path && rm -f $remote_package_path.war"

  # Upload Package from Local to Remote Server
  echo "[ INFO ] Uploading ${CONFIG[package_name]} package to server."
  scp -P ${CONFIG[remote_port]} "${CONFIG[local_path]}/target/${CONFIG[package_name]}.war" $remote_conn:${CONFIG[remote_path]}/webapps/

  # Save change history
  save_history
}

build_if_required() {
  local last_changed_file
  last_changed_file=$(find "${CONFIG[local_path]}" -type f -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)
  if [[ ! "$last_changed_file" == *.war ]]; then
    echo "[ WARN ] Last built ${CONFIG[package_name]} may not be up-to-date. Do you want to rebuild package? (Y/n): ${CONFIG[is_build]}"
    is_build=${CONFIG[is_build]}
    [[ -z ${CONFIG[is_build]} ]] && read is_build
    if [[ ${is_build^^} == 'YES' || ${is_build^^} == 'Y' ]]; then
      cd ${CONFIG[local_path]}/ && mvn -DskipTests=true clean install | while read line; do
        if [[ "$line" == *"BUILD SUCCESS"* ]]; then
          echo "[ INFO ] mvn build ${CONFIG[package_name]} success."
          break
        elif [[ "$line" == *"ERROR"* ]]; then
          echo $line
          finish 1
        fi
      done
    fi
  fi
}

trace_logs() {
  catched_exception=0 # to catch unchecked exceptions (RuntimeException)
  while read line; do
    if [[ "$line" == *"Started"*"in"*"seconds"* ]]; then
      echo $line
      break
    elif [[ "$line" == *"Application run failed"* ]]; then
      echo $line
      catched_exception=1
      break
    fi
  done < <(ssh -p ${CONFIG[remote_port]} $remote_conn "tail -f ${CONFIG[remote_path]}/logs/catalina.out")
  
  if [[ $catched_exception -eq 1 ]]; then
    echo "[ WARN ] Application crashed, Do you want to rollback? (Y/n): ${CONFIG[is_rollback]}"
    is_rollback=${CONFIG[is_rollback]}
    [[ -z ${CONFIG[is_rollback]} ]] && read is_rollback
    if [[ ${is_rollback^^} == 'YES' || ${is_rollback^^} == 'Y' ]]; then
      operation_mode="Rollback"
      selected_backup="$operation_key"
      rollback
      restart_tomcat
    else
      operation_result="Failure"
    fi
  fi
}

update_package () {
  changed_list=($(cd ${CONFIG[local_path]} && git diff --name-only --diff-filter=d HEAD))
  deleted_list=($(cd ${CONFIG[local_path]} && git diff --name-only --diff-filter=D HEAD))
  to_update_list=()

  # Check changes
  if [[ ${#changed_list[@]} -eq 0 && ${#deleted_list[@]} -eq 0 ]]; then
    echo "[ WARN ] No change detected to able to deploy."
    operation_result="Stopped"
    finish 1
  fi

  # Display changes
  echo "[ INFO ] Changed files detected:"
  for file in "${changed_list[@]}"; do
    echo "  - $file"
  done
  echo "[ INFO ] Deleted files detected:"
  for file in "${deleted_list[@]}"; do
    echo "  - $file"
  done

  # Backup current package on remote server
  backup
  
  # Check package for up-to-date
  build_if_required

  # Check change history on remote server
  check_history

  # Update your changes from Local to Remote Server
  echo "[ INFO ] Starting to update files on server."
  for file in "${changed_list[@]}"; do
    update_file "upload" "$file"
  done
  for file in "${deleted_list[@]}"; do
    update_file "delete" "$file"
  done

  if [ ! ${#to_update_list[@]} -eq 0 ]; then
    echo "[ WARN ] Files to planned update manually :"
    for file in "${to_update_list[@]}"; do
      echo "  - $file"
    done
    echo "  If you updated manually these files, Press any key to continue:"
    read for_wait
  fi

  # Save change history
  save_history

  if [[ ${operation_result^^} == "SUCCESS" ]]; then
    echo "[ INFO ] All changes updated successfully."
  fi
}

update_file() {
  file="$2"
  if [[ " ${to_update_list[@]} " =~ " $file " ]]; then
    return 1
  fi
  if [[ "$file" == src/main/resources/* ]]; then
    resource_path="${file#src/main/resources/}"
    local_file="${CONFIG[local_path]}/target/classes/$resource_path"
    remote_file="$remote_package_path/WEB-INF/classes/$resource_path"
  elif [[ "$file" == src/main/java/* ]]; then
    class_path="${file#src/main/java/}"
    class_path="${class_path%.java}.class"
    local_file="${CONFIG[local_path]}/target/classes/$class_path"
    remote_file="$remote_package_path/WEB-INF/classes/$class_path"
  elif [[ "$file" == src/main/webapp/* ]]; then
    web_path="${file#src/main/webapp/}"
    local_file="${CONFIG[local_path]}/src/main/webapp/$web_path"
    remote_file="$remote_package_path/$web_path"
  else
    to_update_list+=($file)
    echo "[ WARN ] Unhandled file: $file (manual upload may be required)"
    return 1
  fi
  if [[ "$1" == "upload" ]]; then
    echo "[ INFO ] Uploading $file"
    _ssh "mkdir -p \"$(dirname "$remote_file")\""
    _scp "$local_file" "$remote_file"
  elif [[ "$1" == "delete" ]]; then
    echo "[ INFO ] Removing $file"
    _ssh "rm -f \"$remote_file\""
  fi
}

check_history () {
  echo "[ INFO ] Checking history on server."

  remote_branch_files=$(_ssh_out "ls $remote_history_path/*.log")
  for branch_file in $remote_branch_files; do
    remote_branch=$(basename "$branch_file" .log)
    
    if [ "$remote_branch" == "$local_branch" ]; then
      continue
    fi

    remote_branch_last_change=$(_ssh_out "date +%Y_%m_%d__%H_%M -r $remote_history_path/$remote_branch.log")
    branch_history=$(_ssh_out "cat $branch_file")
    for i in "${!changed_list[@]}"; do
      file="${changed_list[$i]}"
      if [[ " ${to_update_list[@]} " =~ " $file " ]]; then
        continue
      fi
      if [[ "$branch_history" == *"$file"* ]]; then
        echo "[ WARN ] $file was changed in $remote_branch branch before (last changed: $remote_branch_last_change)."
        is_overwrite=${CONFIG[is_overwrite]}
        while true; do
          echo "Do you still want to update this file? (Overwrite/Manually/Stop): ${CONFIG[is_overwrite]}"
          [[ -z ${CONFIG[is_overwrite]} ]] && read is_overwrite
          if [[ ${is_overwrite^^} == 'OVERWRITE' || ${is_overwrite^^} == 'O' || ${is_overwrite^^} == 'YES' || ${is_overwrite^^} == 'Y' ]]; then
            changed_line="${file:0:1}-${file:1} overwrited by $operation_date-$local_branch"
            _ssh "sed -i 's|$file|$changed_line|g' $branch_file"
            echo "[ WARN ] $file will upload and overwrite."
            break
          elif [[ ${is_overwrite^^} == 'MANUALLY' || ${is_overwrite^^} == 'M' || ${is_overwrite^^} == 'NO' || ${is_overwrite^^} == 'N' ]]; then
            changed_line="$file may be changed manually by $operation_date-$local_branch"
            _ssh "sed -i 's|$file|$changed_line|g' $branch_file"
            echo "[ WARN ] $file is excluded on upload. But it is included to compare list. Manual upload is required."
            to_update_list+=($file)
            break
          elif [[ ${is_overwrite^^} == 'STOP' || ${is_overwrite^^} == 'S' ]]; then
            echo "[ WARN ] Deploy operation may be cause conflicts."
            operation_result="Stopped"
            finish 1
          else
            echo "[ WARN ] Invalid command. Please type correct command."
            CONFIG[is_overwrite]=""; is_overwrite="" # to avoid infinity loop
          fi
        done
      fi
    done
  done
}

save_history () {
  rm -f changes_$operation_date.log
  _ssh "mkdir -p $remote_history_path/"
  _ssh_out "cat $remote_history_path/$local_branch.log" > changes_$operation_date.log
  echo "--- $operation_date ---" >> changes_$operation_date.log
  for file in "${deleted_list[@]}"; do
    echo "deleted $file" >> changes_$operation_date.log
  done
  for file in "${changed_list[@]}"; do
    echo "updated $file" >> changes_$operation_date.log
  done
  for file in "${to_update_list[@]}"; do
    echo "updated $file manually" >> changes_$operation_date.log
  done
  _scp "changes_$operation_date.log" "$remote_history_path/$local_branch.log"
  rm -f changes_$operation_date.log
}

rollback () {
  backups=($(_ssh_out "ls ${CONFIG[remote_path]}/temp/backups/${CONFIG[package_name]}/ | sort -r"))
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "[ WARN ] No backup folder detected to able to deploy."
    operation_result="STOPPED"
    finish 1
  fi
  if [[ ! -z "$selected_backup" && "$backups" != *"$selected_backup"* ]]; then
    echo "[ WARN ] There is no backup for $selected_backup"
  fi
  if [[ -z "$selected_backup" || "$backups" != *"$selected_backup"* ]]; then
    echo "[ INFO ] Backups on this environment:"
    for i in "${!backups[@]}"; do
      backup="${backups[$i]}"
      echo "  $i - $backup"
    done
    while true; do
      echo "[ INFO ] Which backup do you want to go back to? (index): "
      read selected_index
      if [[ $selected_index -ge 0 && $selected_index -le $((${#backups[@]} - 1)) ]]; then
        selected_backup=${backups[$selected_index]}
        break
      else
        echo "[ WARN ] Invalid index, Please try again."
      fi
    done
  fi
  _ssh "rm -f $remote_package_path.war"
  _ssh "cp -rfa ${CONFIG[remote_path]}/temp/backups/${CONFIG[package_name]}/$selected_backup/${CONFIG[package_name]}/ ${CONFIG[remote_path]}/webapps/"
}

backup () {
  webapps=$(_ssh_out "ls ${CONFIG[remote_path]}/webapps/")
  if [[ "$webapps" != *"${CONFIG[package_name]}"* ]]; then
    return 1
  fi
  echo "[ INFO ] Do you want to back up ${CONFIG[package_name]} package on server? (Y/n): ${CONFIG[is_backup]}"
  is_backup=${CONFIG[is_backup]}
  [[ -z ${CONFIG[is_backup]} ]] && read is_backup
  if [[ ${is_backup^^} == 'YES' || ${is_backup^^} == 'Y' ]]; then
    _ssh "mkdir -p $remote_backup_path/$operation_key/"
    ssh -p ${CONFIG[remote_port]} $remote_conn "rsync -avq --ignore-errors $remote_package_path $remote_backup_path/$operation_key/" # custom ssh for output
    echo "[ INFO ] Backup is taken in $remote_backup_path/$operation_key/ folder. to rollback :"
    echo "  on remote > cp -rfa $remote_backup_path/$operation_key/${CONFIG[package_name]}/ ${CONFIG[remote_path]}/webapps/"
    echo "  on local  > sh tomcat_deployer.sh rollback $operation_key ..."
  fi
}

restart_tomcat () {
  echo "[ INFO ] Do you want to restart tomcat? (Y/n): ${CONFIG[is_restart]}"
  is_restart=${CONFIG[is_restart]}
  [[ -z ${CONFIG[is_restart]} ]] && read is_restart
  if [[ ${is_restart^^} == 'YES' || ${is_restart^^} == 'Y' ]]; then
    ssh -p ${CONFIG[remote_port]} $remote_conn "cd ${CONFIG[remote_path]}/bin && sh ./shutdown.sh | grep 'Tomcat st' || true && sh ./startup.sh | grep 'Tomcat st'" 2>/dev/null
    trace_logs
  fi
}

finish () {
  # Check Operation Result
  if [[ $1 -eq 1 && ${operation_result^^} == "SUCCESS" ]]; then
    operation_result="Failure"
  fi

  # Restart Tomcat Server if needed
  if [[ $1 -eq 0 && ${operation_result^^} == "SUCCESS" ]]; then
    restart_tomcat
  fi

  echo "[ INFO ] >>> ${operation_mode^^} ${operation_result^^} <<<"
  exit $1
}

after_error () {
  operation_result="Failure"
  if [ $skip_ssh_errors -eq 0 ]; then
    finish 1
  fi
}

catch_error () {
  while IFS= read -r line; do
    if [[ "$line" != "Authorized users only." && "$line" != *"All activity may be monitored and reported." ]]; then
      echo "$1 : $line"
      return 1
    fi
  done
  echo "  $1 executed successfully."
  return 0
}

_ssh () {
  ssh -p ${CONFIG[remote_port]} $remote_conn $1 2>&1 | catch_error "SSH command"
  if [ $? -eq 1 ]; then
    after_error 0
  fi
}

_ssh_out () {
  ssh -p ${CONFIG[remote_port]} $remote_conn $1 2>/dev/null
}

_scp () {
  scp -P ${CONFIG[remote_port]} $1 $remote_conn:$2 2>&1 | catch_error "Upload operation"
  if [ $? -eq 1 ]; then
    after_error 0
  fi
}

####################################################################################################

init () {
  # Check git repo
  if [[ ! -f ${CONFIG[local_path]}/.git/ ]]; then
    local_branch=$(cd ${CONFIG[local_path]} && git branch --show-current)
  fi
  operation_key="${operation_date}__${operation_mode}__${local_branch}"

  # Display Initial Information
  echo "------------------------------ ${deployer_name^^} ----------------------- $deployer_version"
  echo "[ INFO ] Starting for $operation_mode mode."
  echo "  remote_user  : ${CONFIG[remote_user]}"
  echo "  remote_ip    : ${CONFIG[remote_ip]}"
  echo "  remote_port  : ${CONFIG[remote_port]}"
  echo "  remote_path  : ${CONFIG[remote_path]}"
  echo "  local_path   : ${CONFIG[local_path]}"
  echo "  local_branch : $local_branch"
  echo "  package_name : ${CONFIG[package_name]}"
  echo "----------------------------------------------------------------------------"
  
  # Check Required Options
  if [ -z "${CONFIG[remote_user]}" ] || [ -z "${CONFIG[remote_ip]}" ] || [ -z "${CONFIG[remote_port]}" ] || [ -z "${CONFIG[remote_path]}" ] || [ -z "${CONFIG[local_path]}" ] || [ -z "${CONFIG[package_name]}" ]; then
    echo "[ WARN ] Missing required options. Please provide all required options."
    echo "  Please check the help information with -h or --help."
    finish 1
  fi
  
  # Check Local Configuration
  if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "[ WARN ] You need to create SSH KEY named id_rsa. Recommended to pass the password steps directly."
    echo "  $ ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa"
    finish 1
  fi
  local_id_rsa=$(cat ~/.ssh/id_rsa.pub)

  # Check And Authorize Remote Configuration
  ssh -p ${CONFIG[remote_port]} $remote_conn "grep -Fxq \"$local_id_rsa\" ~/.ssh/authorized_keys || echo \"$local_id_rsa\" >> ~/.ssh/authorized_keys" 2>&1
  ssh_exit_code=$?
  if [ $ssh_exit_code -ne 0 ]; then
    finish 1
  fi

  # Check and Execute Operation
  if [[ ${operation_mode^^} == "DEPLOY" ]]; then
    deploy_package
  elif [[ ${operation_mode^^} == "UPDATE" ]]; then
    update_package
  elif [[ ${operation_mode^^} == "ROLLBACK" ]]; then
    rollback
  else
    echo "[ WARN ] Invalid operation mode: $operation_mode"
    finish 1
  fi
}

init
finish 0