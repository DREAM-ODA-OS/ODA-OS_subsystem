#!/bin/sh
#
# set the resource limits
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Setting the resource limits ... "

[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
#[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

info "Setting the limits on number of open files."
cat >"/etc/security/limits.d/80-nofile.conf" <<END
# Default limit for number of open files

*          soft    nofile     2048
*          hard    nofile     2048 
$ODAOSUSER      soft    nofile     500000 
$ODAOSUSER      hard    nofile     500000 
root       soft    nofile     500000 
root       hard    nofile     500000 
END
