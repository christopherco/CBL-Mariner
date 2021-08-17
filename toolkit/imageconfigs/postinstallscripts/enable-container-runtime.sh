#!/bin/bash

# Enable docker service to start by default
systemctl enable docker

# Workaround issue where containerd service fails due to the service expecting
# modprobe of overlay module to succeed before starting the service. In some of
# our configurations, the overlay module is built into kernel instead of as an
# loadable kernel module
sed -i '/ExecStartPre/d' /lib/systemd/system/containerd.service

# For now, disable all iptables rules (allow all)
cat <<EOF >> /etc/systemd/scripts/iptables
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
#Then flush the rules:
iptables -F INPUT
iptables -F OUTPUT
iptables -F FORWARD
 
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT
#Then flush the rules:
ip6tables -F INPUT
ip6tables -F OUTPUT
ip6tables -F FORWARD
EOF