#!/bin/sh
#
# install GDAL library and tools
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing GDAL library ... "

#======================================================================
#END
# use the testing repository
{ ex /etc/yum.repos.d/eox-testing.repo || true ; } <<END
1,\$s/ gdal-eox\*//
/\[eox-testing\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 gdal-eox*/
/\[eox-testing-source\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 gdal-eox*/
/\[eox-testing-noarch\]
/^[ 	]*includepkgs[ 	]*=.*\$/
s/^\([ 	]*includepkgs[ 	]*=.*\)\$/\1 gdal-eox*/
wq
END

# reset yum cache
yum clean all

rpm -ev --nodeps `rpm -qa | grep '^gdal'` || true
yum --assumeyes install gdal-eox gdal-eox-python proj-epsg
yum --assumeyes install gdal-eox-driver-dimap gdal-eox-driver-envisat \
    gdal-eox-driver-netcdf gdal-eox-driver-openjpeg2
