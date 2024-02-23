#!/bin/sh
modprobe pcnet32
modprobe e1000
ifup eth0
telnetd &
