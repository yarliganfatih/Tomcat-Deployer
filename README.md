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
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.9
[ INFO ] Starting for deploy mode.
  remote_user  : yarligan
  remote_ip    : localhost
  remote_port  : 2222
  remote_path  : /opt/tomcat9
  local_path   : /c/Users/Fatih/restapi
  local_branch : feature_test
  package_name : restapi_draft
----------------------------------------------------------------------------
[ INFO ] Do you want to back up restapi_draft package on server? (Y/n):
y
  SSH command executed successfully.
[ INFO ] Backup is taken in /opt/tomcat9/temp/backups/restapi_draft/2026_01_01__16_35__deploy__feature_test/ folder. to rollback :
  on remote > cp -rfa /opt/tomcat9/temp/backups/restapi_draft/2026_01_01__16_35__deploy__feature_test-test/restapi_draft/ /opt/tomcat9/webapps/
  on local  > sh tomcat_deployer.sh rollback 2026_01_01__16_35__deploy__feature_test ...
[ WARN ] Last built restapi_draft may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build restapi_draft success.
[ INFO ] Checking history on server.
[ WARN ] restapi_draft.war was changed in feature branch before (last changed: 2025_12_29__22_11).
Do you still want to update this file? (Overwrite/Manually/Stop): 
overwrite
  SSH command executed successfully.
[ WARN ] restapi_draft.war will upload and overwrite.
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
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.9
[ INFO ] Starting for update mode.
  remote_user  : yarligan
  remote_ip    : localhost
  remote_port  : 2222
  remote_path  : /opt/tomcat9
  local_path   : /c/Users/Fatih/restapi
  local_branch : feature_test
  package_name : restapi_draft
----------------------------------------------------------------------------
[ INFO ] Changed files detected:
  - pom.xml
  - src/main/java/com/draft/restapi/model/User.java
  - src/main/resources/application.properties
[ INFO ] Deleted files detected:
  - src/main/java/com/draft/restapi/controller/UserController.java
[ INFO ] Do you want to back up restapi_draft package on server? (Y/n):
y
  SSH command executed successfully.
[ INFO ] Backup is taken in /opt/tomcat9/temp/backups/restapi_draft/2026_01_01__16_40__update__feature_test/ folder. to rollback :
  on remote > cp -rfa /opt/tomcat9/temp/backups/restapi_draft/2026_01_01__16_40__update__feature-test/restapi_draft/ /opt/tomcat9/webapps/
  on local  > sh tomcat_deployer.sh rollback 2026_01_01__16_40__update__feature_test ...
[ WARN ] Last built restapi_draft may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build restapi_draft success.
[ INFO ] Checking history on server.
[ WARN ] src/main/java/com/draft/restapi/model/User.java was changed in test-deployer branch before (last changed: 2025_12_24__22_44).
Do you still want to update this file? (Overwrite/Manually/Stop): 
overwrite
  SSH command executed successfully.
[ WARN ] src/main/java/com/draft/restapi/model/User.java will upload and overwrite.
[ WARN ] src/main/resources/application.properties was changed in test-deployer branch before (last changed: 2025_12_24__22_44).
Do you still want to update this file? (Overwrite/Manually/Stop):
manually
[ WARN ] src/main/resources/application.properties is excluded on upload. But it is included to compare list. Manual upload is required.
[ INFO ] Starting to update files on server.
[ WARN ] Unhandled file: pom.xml (manual upload may be required)
[ INFO ] Uploading src/main/java/com/draft/restapi/model/User.java
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] Removing src/main/java/com/draft/restapi/controller/UserController.java
  SSH command executed successfully.
[ WARN ] Files to planned update manually :
  - pom.xml
  - src/main/resources/application.properties
  If you updated manually these files, Press any key to continue:

[ INFO ] All changes updated successfully.
[ INFO ] Do you want to restart tomcat? (Y/n):
y
Tomcat started.
[ INFO ] >>> UPDATE SUCCESS <<<
```

### Rollback Mode
Rollback your changes from the last backups.
```sh
$ sh ./tomcat_deployer.sh rollback --remote-user yarligan -remote-ip localhost --remote-port 2222 --remote-path /opt/tomcat9 --local-path /c/Users/Fatih/restapi --package-name restapi_draft
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.9
[ INFO ] Starting for rollback mode.
  remote_user  : yarligan
  remote_ip    : localhost
  remote_port  : 2222
  remote_path  : /opt/tomcat9
  local_path   : /c/Users/Fatih/restapi
  local_branch : feature_test
  package_name : restapi_draft
----------------------------------------------------------------------------
[ INFO ] Backups on this environment:
  0 - 2026_01_01__16_40__update__feature_test
  1 - 2026_01_01__16_35__deploy__feature_test
  2 - 2026_01_01__15_21__update__main
  3 - 2026_01_01__15_16__update__main
  4 - 2026_01_01__15_10__deploy__main
[ INFO ] Which backup do you want to go back to? (index):
0
  SSH command executed successfully.
  SSH command executed successfully.
[ INFO ] Do you want to restart tomcat? (Y/n):
y
Tomcat started.
[ INFO ] >>> ROLLBACK SUCCESS <<<
```