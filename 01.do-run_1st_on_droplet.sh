#!/bin/bash
#FIXME:
# 1. add error handling for every command
# 2. ask user if they want to continue after every error
# 3. never reboot if there were errors

show_help() {
    cat << HELP
Usage: $(basename $0) -u <username> -p <new ssh port>

HELP
}

what_it_does() {
    cat << NOTICE
This script is intended to run on a newly created cloud server and follow
some basic security guidelines. This script will do the following:

  1. Backup /etc directory to $backup.tar.gz
  2. Add a user ($username) and include them in sudo group
  3. Install curl, pwgen, ufw, latest updates
  4. Harden ssh
        Port=${SSH_SETTINGS[Port]}
        AllowUsers=${SSH_SETTINGS[AllowUsers]}
        LoginGraceTime=${SSH_SETTINGS[LoginGraceTime]}
        PermitRootLogin=${SSH_SETTINGS[PermitRootLogin]}
  5. Apply following rules to ubuntu firewall
        ufw default allow outgoing
        ufw default deny incoming
        ufw allow ${SSH_SETTINGS[Port]}/tcp
        ufw enable
  6. Create a settings file for future scripts to read
  7. Download file for preparing for the next stage
  8. REBOOT

NOTICE
test -z "$1" || echo "Logs can be found at ./$1"
}

press_enter_to_continue() {
    test -z "$1" && msg="Press any key to continue: " || msg="$1"
    read -p "$msg" dummy
}

ssh_port=52204
username=louser

while [ $# -gt 0 ]; do
    case $1 in
        -p|--port)
            ssh_port=$2
            shift
            shift
            ;;
        -u|--username)
            username=$2
            shift
            shift
            ;;
        -h|-help|--help)
            show_help
            what_it_does
            exit 0
            ;;
    esac
done

declare -A SSH_SETTINGS 
SSH_SETTINGS["Port"]=$ssh_port
SSH_SETTINGS["AllowUsers"]=$username
SSH_SETTINGS["LoginGraceTime"]=1m
SSH_SETTINGS["PermitRootLogin"]=no

stamp=$(date +%Y-%m-%d)
backup=/root/etc-backup-$stamp

what_it_does $stamp
press_enter_to_continue

mkdir ./$stamp
export DEBIAN_FRONTEND=noninteractive

# backup of /etc
echo -n "Creating backup - "
tar -zcf $backup.tar.gz /etc/ && echo "OK" || echo "Failed"

# create a user
echo -n "Adding user $username - "
(adduser -q $username && usermod -aG sudo $username) && echo "OK" || echo "Failed"

# install packages, upgrading system
echo -n "Running: apt-get update - "
apt-get update >> ./$stamp/apt-get-update.log  2>&1 && echo "OK" || echo "Failed" 

echo -n "Running: apt-get install ufw pwgen curl git - "
apt-get -y install ufw pwgen curl git >> ./$stamp/apt-get-y-install-ufw-pwgen-curl-git.log 2>&1 && echo "OK" || echo "Failed"

echo -n "Running: apt-get -u upgrade - "
apt-get -u -y upgrade >> ./$stamp/apt-get-u-y-upgrade.log 2>&1 && echo "OK" || echo "Failed"

echo -n "Running: apt-get autoremove - "
apt-get -y autoremove >> ./$stamp/apt-get-y-autoremove.log 2>&1 && echo "OK" || echo "Failed"

# ssh settings
sshd_file=/etc/ssh/sshd_config
cp $sshd_file ./$stamp/sshd_config.orig

echo "Updating ssh"
for setting in "${!SSH_SETTINGS[@]}"; do
    before=$(cat $sshd_file | grep -n "^#$setting")

    if [ $? -eq 0 ]; then
        value=$(cat $sshd_file | grep "^#$setting" | awk '{print $2}')
        sed -i "s:^#$setting $value:$setting ${SSH_SETTINGS[$setting]}:g" $sshd_file
    else
        before=$(cat $sshd_file | grep -n "^$setting")

        if [ $? -eq 0 ]; then
            value=$(cat $sshd_file | grep "^$setting" | awk '{print $2}')
            sed -i "s:^$setting $value:$setting ${SSH_SETTINGS[$setting]}:g" $sshd_file
        fi
    fi

    after=$(cat $sshd_file | grep -n "^$setting")

    printf "For $setting:\n\tbefore:\t$before\n\tafter:\t$after\n"
done

msg="Check ssh settings. If wrong, fix it yourself. To continue, press enter: "
press_enter_to_continue "$msg"

echo "Updating ufw rules"
ufw default allow outgoing
ufw default deny incoming
ufw allow ${SSH_SETTINGS[Port]}/tcp
ufw enable
ufw status

cat > ./$stamp/hardening.conf << HARDENING
# This file was created by script: $(basename $0), user: $USER
user=$username
ssh_port=${SSH_SETTINGS[Port]}
ssh_allowusers=${SSH_SETTINGS[AllowUsers]}
ssh_logingracetime=${SSH_SETTINGS[LoginGraceTime]}
ssh_permitrootlogin=${SSH_SETTINGS[PermitRootLogin]}
HARDENING

echo -n "Creating config file in /home/$username/.hardening.conf: "
cp ./$stamp/hardening.conf /home/$username/.hardening.conf && echo "OK" || echo "Failed"

cat > ./$stamp/next-stage.sh << NEXT_STAGE
#!/bin/bash
source /home/$username/.hardening.conf
export $(cut -d= -f1 /home/$username/.hardening.conf)

ssh-keygen
cat /home/$username/.ssh/id_rsa.pub

echo
echo "------------------------------------------------------------"
echo "Copy the above SSH key to your github profile."
read -p "Once copied, press enter to continue: "

git clone git@github.com:ashakunt/scripts.git /home/$username/scripts

echo "------------------------------------------------------------"
echo "Done. If there were errors, please try again. Next steps:
echo "    1. $ cd /home/$username/scripts"
echo "    2. $ ./02.do-run_2nd_on_droplet.sh"

NEXT_STAGE

echo -n "Creating script for preparing next stage: "
(cp ./$stamp/next-stage.sh /home/$username/ && chmod +x /home/$username/next-stage.sh) && echo "OK" || echo "Failed"

server_ip=$(ifconfig eth0 | grep "inet " | awk {'print $2'})

echo "-----------------------------------------------------------------------------"
echo "Done. If there were any errors, we recommend to restore backup and try again."
echo
echo "For server login: ssh -p ${SSH_SETTINGS[Port]} $username@$server_ip"
echo "On next login, run this: $ next-stage.sh"

press_enter_to_continue "Press enter to reboot: " 

reboot
