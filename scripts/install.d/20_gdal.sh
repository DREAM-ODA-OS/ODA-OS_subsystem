#!/bin/sh
#
# install GDAL library and tools
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing GDAL library ... "

#======================================================================
## do not use the testing repository
#ex /etc/yum.repos.d/eox-testing.repo <<END
#/\[eox-testing\]
#/^[ 	]*exclude[ 	]*=.*\$/
#s/^\([ 	]*exclude[ 	]*=.*\)\$/\1 gdal-eox*/
#/\[eox-testing-source\]
#/^[ 	]*exclude[ 	]*=.*\$/
#s/^\([ 	]*exclude[ 	]*=.*\)\$/\1 gdal-eox*/
#/\[eox-testing-noarch\]
#/^[ 	]*exclude[ 	]*=.*\$/
#s/^\([ 	]*exclude[ 	]*=.*\)\$/\1 gdal-eox*/
#wq
#END

# reset yum cache
#yum clean all

yum --assumeyes install gdal-eox gdal-eox-python \
    gdal-eox-driver-dimap gdal-eox-driver-envisat \
    gdal-eox-driver-netcdf gdal-eox-driver-openjpeg2 \
    proj-epsg

