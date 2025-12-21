# Tomcat Deployer
Transfer only your changed files from your local to remote with a single command.

## Get Started
1. Create a SSH Key for your local with this command :
Recommended to pass the password steps directly.
```sh
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa
```
Example:
```sh
$ ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa
Generating public/private rsa key pair.
Created directory '/c/Users/Fatih/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again: 
Your identification has been saved in /c/Users/Fatih/.ssh/id_rsa
Your public key has been saved in /c/Users/Fatih/.ssh/id_rsa.pub
The key fingerprint is:
...
```

2. Clone this repository and run this command :
```sh
sh tomcat_deployer.sh [operation] [options] [<goal(s)>] [<phase(s)>]
```

## Deployment Scenario

```sh
$ sh ./tomcat_deployer.sh deploy --remote-user yarligan -remote-ip localhost --remote-port 2222 --remote-path /opt/tomcat9 --local-path /c/Users/Fatih/restapi --package-name restapi_draft
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.5
[ INFO ] Starting for deploy mode.
  remote_user  : yarligan
  remote_ip    : localhost
  remote_port  : 2222
  remote_path  : /opt/tomcat9
  local_path   : /c/Users/Fatih/restapi
  package_name : restapi_draft
----------------------------------------------------------------------------
[ INFO ] Do you want to back up restapi_draft package on server? (Y/n):
y
  SSH command executed successfully.
[ INFO ] Backup is taken in /opt/tomcat9/temp/backups/restapi_draft/2025_12_21__18_46/ folder.
[ INFO ] You can rollback with this command on remote server :
  > cp -rfa /opt/tomcat9/temp/backups/restapi_draft/2025_12_21__18_46/restapi_draft/ /opt/tomcat9/webapps/
[ WARN ] Last built restapi_draft may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build restapi_draft success.
[ INFO ] Removing current restapi_draft package on server.
  SSH command executed successfully.
[ INFO ] Uploading restapi_draft package to server.
restapi_draft.war                                                                                            100%   43MB 115.2MB/s   00:00    
[ INFO ] Do you want to restart tomcat? (Y/n):
y
Tomcat started.
[ INFO ] >>> DEPLOY SUCCESS <<<
```

### Update Mode
Transfer only your changed files by git command.
```sh
$ sh ./tomcat_deployer.sh update --remote-user yarligan -remote-ip localhost --remote-port 2222 --remote-path /opt/tomcat9 --local-path /c/Users/Fatih/restapi --package-name restapi_draft
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.5
[ INFO ] Starting for update mode.
  remote_user  : yarligan
  remote_ip    : localhost
  remote_port  : 2222
  remote_path  : /opt/tomcat9
  local_path   : /c/Users/Fatih/restapi
  package_name : restapi_draft
----------------------------------------------------------------------------
[ INFO ] Changed files detected:
  - src/main/java/com/draft/restapi/model/User.java
  - src/main/resources/application.properties
[ INFO ] Do you want to back up restapi_draft package on server? (Y/n):
y
  SSH command executed successfully.
[ INFO ] Backup is taken in /opt/tomcat9/temp/backups/restapi_draft/2025_12_21__18_08/ folder.
[ INFO ] You can rollback with this command on remote server :
  > cp -rfa /opt/tomcat9/temp/backups/restapi_draft/2025_12_21__18_08/restapi_draft/ /opt/tomcat9/webapps/
[ WARN ] Last built restapi_draft may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build restapi_draft success.
[ INFO ] Starting to upload files to server.
[ INFO ] Uploading src/main/java/com/draft/restapi/model/User.java
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] Uploading src/main/resources/application.properties
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] All changes updated successfully.
[ INFO ] Do you want to restart tomcat? (Y/n):
y
Tomcat started.
[ INFO ] >>> UPDATE SUCCESS <<<
```