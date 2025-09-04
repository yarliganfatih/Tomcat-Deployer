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
$ sh tomcat_deployer.sh deploy --remote-user root --remote-ip remotehost --remote-path /usr/share/tomcat --local-path /c/Users/Fatih/myJavaProject --package-name my-java-project
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.4
[ INFO ] Starting for deploy mode.
  remote_user  : root
  remote_ip    : remotehost
  remote_path  : /usr/share/tomcat
  local_path   : /c/Users/Fatih/myJavaProject
  package_name : my-java-project
----------------------------------------------------------------------------
Authorized users only. All activity may be monitored and reported.
Do you want to back up my-java-project package on server? (Y/n):
y
  SSH command executed successfully.
Authorized users only. All activity may be monitored and reported.
[ INFO ] Backup is taken in /usr/share/tomcat/temp/backups/my-java-project/ folder.
[ INFO ] You can rollback with this command on remote server :
  > cp -rfa /usr/share/tomcat/temp/backups/my-java-project/ /usr/share/tomcat/webapps/
[ WARN ] Last built my-java-project may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build my-java-project success.
Authorized users only. All activity may be monitored and reported.
my-java-project.war                                                     100%
Do you want to restart tomcat? (Y/n):
y
Authorized users only. All activity may be monitored and reported.
Tomcat stopped.
Tomcat started.
[ INFO ] >>> DEPLOY SUCCESS <<<
```

### Update Mode
Transfer only your changed files by git command.
```sh
$ sh tomcat_deployer.sh update --remote-user root --remote-ip remotehost --remote-path /usr/share/tomcat --local-path /c/Users/Fatih/myJavaProject --package-name my-java-project
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.4
[ INFO ] Starting for update mode.
  remote_user  : root
  remote_ip    : remotehost
  remote_path  : /usr/share/tomcat
  local_path   : /c/Users/Fatih/myJavaProject
  package_name : my-java-project
----------------------------------------------------------------------------
Authorized users only. All activity may be monitored and reported.
[ INFO ] Changed files detected:
  - src/main/resources/applicationContext.xml
  - src/main/java/com/myjavaproject/MyApplication.java
  - src/main/webapp/index.html
Do you want to back up my-java-project package on server? (Y/n):
y
  SSH command executed successfully.
Authorized users only. All activity may be monitored and reported.
[ INFO ] Backup is taken in /usr/share/tomcat/temp/backups/my-java-project/ folder.
[ INFO ] You can rollback with this command on remote server :
  > cp -rfa /usr/share/tomcat/temp/backups/my-java-project/ /usr/share/tomcat/webapps/
[ WARN ] Last built my-java-project may not be up-to-date. Do you want to rebuild package? (Y/n):
y
[ INFO ] mvn build my-java-project success.
[ INFO ] Starting to upload files to server.
[ INFO ] Uploading src/main/resources/applicationContext.xml
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] Uploading src/main/java/com/myjavaproject/MyApplication.java
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] Uploading src/main/webapp/index.html
  SSH command executed successfully.
  Upload operation executed successfully.
[ INFO ] All changes updated successfully.
Do you want to restart tomcat? (Y/n):
y
Authorized users only. All activity may be monitored and reported.
Tomcat stopped.
Tomcat started.
[ INFO ] >>> UPDATE SUCCESS <<<
```