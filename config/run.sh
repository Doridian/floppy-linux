#!/bin/sh
modprobe e1000
ifup eth0
mkdir /tmp/mnt

ping 8.8.8.8
#mount -t nfs 10.2.11.1:/mnt/zhdd/nas /tmp/mnt &
