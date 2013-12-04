#!/bin/sh
#
# install Rasdaman RPMs 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing Rasdaman ... "

#======================================================================

# enable eox-testing repository 
ex /etc/yum.repos.d/eox-testing.repo <<END
1,\$s/^[ 	]*enabled[ 	]*=.*\$/enabled=1/
wq 
END

# reset yum cache
yum clean all

# install RPMs 
yum --assumeyes install rasdaman rasdaman-petascope
