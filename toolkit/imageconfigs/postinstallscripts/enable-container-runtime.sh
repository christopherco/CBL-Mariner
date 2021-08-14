#!/bin/bash

# Enable docker service to start by default
systemctl enable docker

sed -i '/ExecStartPre/d' /lib/systemd/system/containerd.service