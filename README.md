# scripts
Various scripts that are helpful in many ways. Multiple languages.

## Helper scripts for basic hardening of a server on digitalocean

**Pre-requisites**
* Enter the below content in `User data` section when creating a droplet

```
#!/bin/bash
echo "Running user data step: " | tee /root/userdata.log
wget https://raw.githubusercontent.com/ashakunt/scripts/master/01.do-run_1st_on_droplet.sh -O /root/run_me_first.sh -o /root/userdata.log
chmod +x /root/run_me_first.sh
```

* Once the droplet is created, do the following:
    * Login as root
    * `$ cd /root && ./run_me_first.sh -u <username> -p <new ssh port>`
    
Upon completion, the script will prompt you to reboot and after that, root login is disabled already, so remember to copy down the login information that is given once the script finishes its execution. It looks something like: `ssh -p <ssh port> <user>@<droplet-ip-address>`

* After reboot and login as `<user>`, run the automatic generated script `prepare-stage.sh` which clones this github repo
* Next hardening step is to run `02.do-run_2nd_on_droplet.sh` 
* Followed by `task-*` of your choice. 

## What has happened so far?
1. Added a user
1. Disabled root login for user over SSH
1. Setup SSH to run on a random port (chosen by you or defaults to 52204)
1. Sets UFW to allow outgoing, deny incoming, allow tcp over SSH port
1. Secure the shared memory
1. Harden the network using sysctl
1. Install fail2ban and configure it to keep checking the SSH traffic
1. SSH Key has been generated

## Available tasks 
* Configure sending emails for system notifications using postfix and mailgun
* TBD: Install LAMP stack
* TBD: Install LEMP stack
* TBD: Install independently - `mysql`, `php5.6+`, `apache`, `nginx`

## What more could be done? (depends on usecase and how you want to secure)
* Fail2ban - update its configuration
* Apache hardening (w.r.t SSL, Server Signature and prevent information leakage)
* Disable DNS recursion and remove version information from bind
* Hardening of PHP
* DenyHosts
* 
