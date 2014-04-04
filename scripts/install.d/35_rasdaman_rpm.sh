#!/bin/sh
#
# install Rasdaman RPMs 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing Rasdaman ... "

#======================================================================

#TODO: testing repo conflicts 

info "Enabling Rasdaman packages from the EOX testing repository... "
ex /etc/yum.repos.d/eox-testing.repo <<END
/\[eox-testing\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 rasdaman*/
/\[eox-testing-source\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 rasdaman*/
/\[eox-testing-noarch\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 rasdaman*/
wq 
END

# reset yum cache
yum clean all

# install RPMs 
yum --assumeyes install rasdaman rasdaman-petascope

