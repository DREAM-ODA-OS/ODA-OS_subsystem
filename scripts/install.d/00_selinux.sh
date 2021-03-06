#!/bin/sh
#
# disable SELinux 
#

. `dirname $0`/../lib_logging.sh  

info "Disabling SELinux ..."

# change to permissive mode in the current session 
[ `getenforce` != "Disabled" ] && setenforce "Permissive"

# disable SELinux permanently 
sed -e 's/^[ 	]*SELINUX=/SELINUX=disabled/' -i /etc/selinux/config
