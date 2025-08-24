#!/bin/bash

# Deployer Information
deployer_name="Tomcat Deployer"
deployer_version="0.0.2"

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
-r, -remote-path,    --remote-path <path>    Remote server path (Tomcat path) to deploy.
-l, -local-path,     --local-path <path>     Local path of your project.
-p, -package-name,   --package-name <name>   Package name to deploy.
EOF
}

options=$(getopt -l "help,version,verbose,xtrace,remote-user:,remote-ip:,remote-path:,local-path:,package-name:" -o "hvVXu:i:r:l:p:" -a -- "$@")
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
  -r|--remote-path)
    remote_path="$2";;
  -l|--local-path)
    local_path="$2";;
  -p|--package-name)
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

# Global Variables
remote_conn="$remote_user@$remote_ip"

####################################################################################################

deploy_package () {
  # Check package for up-to-date
  build_if_required

  # Upload Package from Local to Remote Server
  scp "$local_path/target/$package_name.war" $remote_conn:$remote_path/webapps/
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

restart_tomcat () {
  echo "Do you want to restart tomcat? (Y/n):"
  read is_restart
  if [[ ${is_restart^^} == 'YES' || ${is_restart^^} == 'Y' ]]; then
    ssh $remote_conn "cd $remote_path/bin && JAVA_HOME=/usr/java/latest ./shutdown.sh | grep 'Tomcat st' || true && JAVA_HOME=/usr/java/latest ./shutdown.sh | grep 'Tomcat st' || true && JAVA_HOME=/usr/java/latest ./startup.sh | grep 'Tomcat st'" 2>/dev/null
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

####################################################################################################

init () {
  # Display Initial Information
  echo "------------------------------ ${deployer_name^^} ----------------------- $deployer_version"
  echo "[ INFO ] Starting for $operation_mode mode."
  echo "  remote_user  : $remote_user"
  echo "  remote_ip    : $remote_ip"
  echo "  remote_path  : $remote_path"
  echo "  local_path   : $local_path"
  echo "  package_name : $package_name"
  echo "----------------------------------------------------------------------------"

  # Check Local Configuration
  if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "[ WARN ] You need to create SSH KEY named id_rsa. Recommended to pass the password steps directly."
    echo "  $ ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa"
    finish 1
  fi
  local_id_rsa=$(cat ~/.ssh/id_rsa.pub)

  # Check And Authorize Remote Configuration
  ssh $remote_conn "grep -Fxq \"$local_id_rsa\" ~/.ssh/authorized_keys || echo \"$local_id_rsa\" >> ~/.ssh/authorized_keys" 2>&1
  ssh_exit_code=$?
  if [ $ssh_exit_code -ne 0 ]; then
    finish 1
  fi
  
  # Check Required Options
  if [ -z "$remote_user" ] || [ -z "$remote_ip" ] || [ -z "$remote_path" ] || [ -z "$local_path" ] || [ -z "$package_name" ]; then
    echo "[ WARN ] Missing required options. Please provide all required options."
    echo "  Please check the help information with -h or --help."
    finish 1
  fi

  # Check and Execute Operation
  if [[ ${operation_mode^^} == "DEPLOY" ]]; then
    deploy_package
  else
    echo "[ WARN ] Invalid operation mode: $operation_mode"
    finish 1
  fi
}

init
finish 0