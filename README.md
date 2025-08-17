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
------------------------------ TOMCAT DEPLOYER ----------------------- 0.0.1
[ INFO ] Starting for deploy mode.
  remote_user  : root
  remote_ip    : remotehost
  remote_path  : /usr/share/tomcat
  local_path   : /c/Users/Fatih/myJavaProject
  package_name : my-java-project
----------------------------------------------------------------------------
Authorized users only. All activity may be monitored and reported.
Authorized users only. All activity may be monitored and reported.
my-java-project.war                                                     100%
Do you want to restart tomcat? (Y/n):
y
Authorized users only. All activity may be monitored and reported.
Tomcat stopped.
Tomcat started.
[ INFO ] >>> DEPLOY SUCCESS <<<
```