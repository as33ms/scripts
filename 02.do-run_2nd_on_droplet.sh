#!/bin/bash
stamp=$(date +%Y-%m-%d)
config_file=$HOME/.hardening.conf

test -f $config_file && echo "Found config file." || failure_exit "Missing config file: $config_file"

source $config_file
export $(cut -d= -f1 $config_file) || failure_exit "Unable to export saved config from 01.do-run_1st_on_droplet.sh."

show_help() {
    :
}

failure_exit() {
    echo "$@" && exit 1
}

what_it_does() {
    cat << NOTICE
This script is intended to run on a newly created cloud server and follow
some basic security guidelines. This script will do the following:

  1. Secure the shared memory
  2. Harden the network using sysctl
  3. Install fail2ban and configure

NOTICE
}

mkdir ./$stamp

# secure shared memory
echo -n "Adding entry for securing shared memory: "
content="tmpfs  /run/shm    tmpfs   defaults,noexec,nosuid 0 0"
echo "$content" | sudo tee -a /etc/fstab > /dev/null && echo "OK" || failure_exit "Failed to secure shared memory"

# ip hardening
ip_sec=50-ip-sec.conf

cat > ./$stamp/$ip_sec << IP_SECURING

# below config added by $USER, script: $(basename $0)

# Disable Source Routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable acceptance of all ICMP redirected packets on all interfaces
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable send IPv4 redirect packets
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Set Reverse Path Forwarding to strict mode as defined in RFC 3704
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Block pings
net.ipv4.icmp_echo_ignore_all = 1

# Syn flood help
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log suspicious martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians=1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 auto config
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.eth0.accept_ra=0
net.ipv6.conf.eth0.autoconf=0

# ^above config added by $USER, script: $(basename $0)

IP_SECURING

echo -n "Copying $ip_sec configuration: "
sudo cp ./$stamp/$ip_sec /etc/sysctl.d/$ip_sec && echo "OK" || failure_exit "Failed to harden system network"

echo -n "Reloading sysctl configuration: "
sudo sysctl -p && echo "OK" || failure_exit "Failed to reload sysctl"

echo -n "Installing fail2ban: "
sudo apt-get install -y fail2ban >> ./$stamp/apt-get-install-y-fail2ban.log 2>&1 && echo "OK" || failure_exit "Failed to install fail2ban"

ssh_jail=ssh.conf
cat > ./$stamp/$ssh_jail << SSH_JAIL
#ssh jail added by $USER (script: $(basename $0))
[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry= 3
SSH_JAIL

echo -n "Creating jail for ssh: "
sudo cp ./$stamp/$ssh_jail /etc/fail2ban/jail.d/ssh.conf && echo "OK" || failure_exit "Failed to create ssh jail [fail2ban]"

echo "Enabling fail2ban"
sudo systemctl start fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd

echo "----------------------------------------------------------"
echo "Done. If there were any errors, we recommend to try again."
echo "Next steps:"
echo " 1. To install lamp: $ task-install_lamp.sh"
