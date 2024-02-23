#!/bin/sh
modprobe pcnet32
ifup eth0
telnetd &
