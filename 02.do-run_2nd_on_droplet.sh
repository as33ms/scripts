#!/bin/bash
f=$(basename $0)
c_file=$HOME/.system-setup.conf
test -f $c_file && echo "Found config $c_file." || { echo "$f: Missing config file $c_file" && exit 1; }

source $c_file
export $(cut -d= -f1 $c_file) || { echo "$f: Unable to export config saved by run_1st_on_droplet.sh." && exit 1; }

source $scripts_clonedir/includes.sh

show_help() {
    cat << SHOW_HELP
Usage: $f

This script is intended to run on a newly created cloud server and follow
some basic security guidelines. This script will do the following:

  1. Secure the shared memory
  2. Harden the network using sysctl
  3. Install fail2ban and configure

SHOW_HELP
}

logdir=$scripts_setupdir
setupdir=$scripts_setupdir

test -d $scripts_setupdir || mkdir -p $scripts_setupdir

# secure shared memory
echo -n "Adding entry for securing shared memory: "
content="tmpfs  /run/shm    tmpfs   defaults,noexec,nosuid 0 0"
echo "$content" | sudo tee -a /etc/fstab > /dev/null && echo "OK" || fexit "Failed"

# ip hardening
ipsec=50-ip-sec.conf
cp $scripts_clonedir/confs/$ipsec $setupdir/$ipsec
sed -i "1s/^/# below config added by $USER, script: $f\n/" $setupdir/$ipsec
echo "# above config added by $USER, script: $f" | tee -a $setupdir/$ipsec > /dev/null

echo -n "Copying $ipsec to /etc/sysctl.d: "
sudo cp $setupdir/$ipsec /etc/sysctl.d/$ipsec && echo "OK" || fexit "Failed"

echo -n "Reloading sysctl configuration: "
sudo sysctl -p && echo "OK" || fexit "Failed"

echo -n "Installing fail2ban: "
sudo apt-get install -y fail2ban >> $logdir/apt-get-install-y-fail2ban.log 2>&1 && echo "OK" || fexit "Failed"

echo -n "Creating backup of /etc: "
sudo tar -zcf $setupdir/backup-post-install-fail2ban.tar.gz /etc/ && echo "OK" || fexit "Failed to create backup"

# adding ssh jail for fail2ban
f2bdir=/etc/fail2ban
ssh_jail=f2b-jail-ssh.conf
cp $scripts_clonedir/confs/$ssh_jail $setupdir/$ssh_jail
sed -i "s:_PORT_:$ssh_port:g" $setupdir/$ssh_jail
sed -i "1s/^/# ssh jail added by $USER, script: $f\n/" $setupdir/$ssh_jail

echo -n "Copying $ssh_jail to $f2bdir/jail.d: "
sudo cp $setupdir/$ssh_jail $f2bdir/jail.d/$ssh_jail && echo "OK" || fexit "Failed"

# setting default action in fail2ban
cp $f2bdir/jail.conf $setupdir/jail.conf.orig
sed -i "s:%(action_)s:%(action_mw)s:g" $setupdir/jail.conf.orig

echo -n "Copying updated jail.conf to $f2bdir: "
sudo cp $setupdir/jail.conf.orig $f2bdir/jail.conf && echo "OK" || fexit "Failed to update jail.conf"

echo -n "Enabling fail2ban: "
sudo systemctl start fail2ban && echo "OK" || fexit "Faild to start fail2ban"

echo "Current fail2ban default action:"
cat $f2bdir/jail.conf | grep "^action = %"

echo "Current status for fail2ban:"
sudo fail2ban-client status
sudo fail2ban-client status sshd

# next steps below:

cat > $setupdir/mailgun.conf << MAILGUN_CONF
mg_user=
mg_pass=
mg_domain=
MAILGUN_CONF

echo "----------------------------------------------------------"
echo "Done. If there were any errors, we recommend to try again."
cat << NEXT_STEPS
Setup postfix for sending emails:           task-setup_postfix.sh

    Pre-requisites:
    1. MailGun SMTP credentials for sending email
        Login to MailGun account and choose the domain you want to
        send email with. Copy its SMTP credentials or then, create
        a new SMTP credential for this specific server.

        Save the credentials as key-value pair in mailgun.conf as

        mg_user=<mailgun username>
        mg_pass=<mailgun password>
        mg_domain=<mailgun domain>

    $ task-setup_postfix.sh -c $setupdir/mailgun.conf

    [HINT]: Remember to add values to mailgun.conf

Setup LAMP on this instance:                task-install_lamp.sh

    Pre-requisites:
NEXT_STEPS
