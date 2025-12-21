#!/bin/bash

# Deployer Information
deployer_name="Tomcat Deployer"
deployer_version="0.0.6"

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

Required options for operaions:
-u, -remote-user,    --remote-user <user>    Remote server user name.
-i, -remote-ip,      --remote-ip <ip>        Remote server IP address.
-p, -remote-port,    --remote-port <port>    Remote server SSH port. Default is 22.
-r, -remote-path,    --remote-path <path>    Remote server path (Tomcat path) to deploy.
-l, -local-path,     --local-path <path>     Local path of your project.
-n, -package-name,   --package-name <name>   Package name to deploy.
EOF
}

# Default Values
remote_user=""
remote_ip=""
remote_port="22"
remote_path="/usr/share/tomcat"
local_path="./"
package_name=""

options=$(getopt -l "help,version,verbose,xtrace,remote-user:,remote-ip:,remote-port:,remote-path:,local-path:,package-name:" -o "hvVXu:i:p:r:l:n:" -a -- "$@")
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
  -u|--remote-user)
    remote_user="$2";;
  -i|--remote-ip)
    remote_ip="$2";;
  -p|--remote-port)
    remote_port="$2";;
  -r|--remote-path)
    remote_path="$2";;
  -l|--local-path)
    local_path="$2";;
  -n|--package-name)
    package_name="$2";;
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

# Global Variables
skip_ssh_errors=1
remote_conn="$remote_user@$remote_ip"
remote_backup_path="$remote_path/temp/backups/$package_name/$operation_date"

####################################################################################################

deploy_package () {
  # Backup current package on remote server
  backup

  # Check package for up-to-date
  build_if_required

  # Remove current package on remote server
  echo "[ INFO ] Removing current $package_name package on server."
  _ssh "rm -rf $remote_path/webapps/$package_name && rm -f $remote_path/webapps/$package_name.war"

  # Upload Package from Local to Remote Server
  echo "[ INFO ] Uploading $package_name package to server."
  scp -P $remote_port "$local_path/target/$package_name.war" $remote_conn:$remote_path/webapps/
}

build_if_required() {
  local last_changed_file
  last_changed_file=$(find "$local_path" -type f -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)
  if [[ ! "$last_changed_file" == *.war ]]; then
    echo "[ WARN ] Last built $package_name may not be up-to-date. Do you want to rebuild package? (Y/n):"
    read is_build
    if [[ ${is_build^^} == 'YES' || ${is_build^^} == 'Y' ]]; then
      cd $local_path/ && mvn -DskipTests=true clean install | while read line; do
        if [[ "$line" == *"BUILD SUCCESS"* ]]; then
          echo "[ INFO ] mvn build $package_name success."
          break
        elif [[ "$line" == *"ERROR"* ]]; then
          echo $line
          finish 1
        fi
      done
    fi
  fi
}

update_package () {
  changed_list=($(cd $local_path && git diff --name-only --diff-filter=d HEAD))
  deleted_list=($(cd $local_path && git diff --name-only --diff-filter=D HEAD))
  to_update_list=()

  # Check changes
  if [[ ${#changed_list[@]} -eq 0 || ${#deleted_list[@]} -eq 0 ]]; then
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

  if [[ ${operation_result^^} == "SUCCESS" ]]; then
    echo "[ INFO ] All changes updated successfully."
  fi
}

update_file() {
  file="$2"
  if [[ "$file" == src/main/resources/* ]]; then
    resource_path="${file#src/main/resources/}"
    local_file="$local_path/target/classes/$resource_path"
    remote_file="$remote_path/webapps/$package_name/WEB-INF/classes/$resource_path"
  elif [[ "$file" == src/main/java/* ]]; then
    class_path="${file#src/main/java/}"
    class_path="${class_path%.java}.class"
    local_file="$local_path/target/classes/$class_path"
    remote_file="$remote_path/webapps/$package_name/WEB-INF/classes/$class_path"
  elif [[ "$file" == src/main/webapp/* ]]; then
    web_path="${file#src/main/webapp/}"
    local_file="$local_path/src/main/webapp/$web_path"
    remote_file="$remote_path/webapps/$package_name/$web_path"
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

backup () {
  echo "[ INFO ] Do you want to back up $package_name package on server? (Y/n):"
  read is_backup
  if [[ ${is_backup^^} == 'YES' || ${is_backup^^} == 'Y' ]]; then
    _ssh "mkdir -p $remote_backup_path/"
    ssh -p $remote_port $remote_conn "rsync -avq --ignore-errors $remote_package_path $remote_backup_path/" # custom ssh for output
    echo "[ INFO ] Backup is taken in $remote_backup_path/ folder."
    echo "[ INFO ] You can rollback with this command on remote server :"
    echo "  > cp -rfa $remote_backup_path/$package_name/ $remote_path/webapps/"
  fi
}

restart_tomcat () {
  echo "[ INFO ] Do you want to restart tomcat? (Y/n):"
  read is_restart
  if [[ ${is_restart^^} == 'YES' || ${is_restart^^} == 'Y' ]]; then
    ssh -p $remote_port $remote_conn "cd $remote_path/bin && sh ./shutdown.sh | grep 'Tomcat st' || true && sh ./startup.sh | grep 'Tomcat st'" 2>/dev/null
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
  ssh -p $remote_port $remote_conn $1 2>&1 | catch_error "SSH command"
  if [ $? -eq 1 ]; then
    after_error 0
  fi
}

_scp () {
  scp -P $remote_port $1 $remote_conn:$2 2>&1 | catch_error "Upload operation"
  if [ $? -eq 1 ]; then
    after_error 0
  fi
}

####################################################################################################

init () {
  # Display Initial Information
  echo "------------------------------ ${deployer_name^^} ----------------------- $deployer_version"
  echo "[ INFO ] Starting for $operation_mode mode."
  echo "  remote_user  : $remote_user"
  echo "  remote_ip    : $remote_ip"
  echo "  remote_port  : $remote_port"
  echo "  remote_path  : $remote_path"
  echo "  local_path   : $local_path"
  echo "  package_name : $package_name"
  echo "----------------------------------------------------------------------------"
  
  # Check Required Options
  if [ -z "$remote_user" ] || [ -z "$remote_ip" ] || [ -z "$remote_port" ] || [ -z "$remote_path" ] || [ -z "$local_path" ] || [ -z "$package_name" ]; then
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
  ssh -p $remote_port $remote_conn "grep -Fxq \"$local_id_rsa\" ~/.ssh/authorized_keys || echo \"$local_id_rsa\" >> ~/.ssh/authorized_keys" 2>&1
  ssh_exit_code=$?
  if [ $ssh_exit_code -ne 0 ]; then
    finish 1
  fi

  # Check and Execute Operation
  if [[ ${operation_mode^^} == "DEPLOY" ]]; then
    deploy_package  
  elif [[ ${operation_mode^^} == "UPDATE" ]]; then
    update_package
  else
    echo "[ WARN ] Invalid operation mode: $operation_mode"
    finish 1
  fi
}

init
finish 0