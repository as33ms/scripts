#!/bin/bash
stamp=$(date +%Y-%m-%d)

show_help() {
    :
}

what_it_does() {
    :
}

mkdir ./$stamp

# secure shared memory
echo -n "Adding entry for securing shared memory: "
content="tmpfs  /run/shm    tmpfs   defaults,noexec,nosuid 0 0"
echo "$content" | sudo tee -a /etc/fstab > /dev/null && echo "OK" || echo "Failed"

# ip hardening
ip_sec=50-ip-sec.conf

cat > ./$stamp/$ip_sec << IP_SECURING

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

IP_SECURING

sudo cp ./$stamp/$ip_sec /etc/sysctl.d/$ip_sec

