#!/bin/sh
#
# install GDAL library and tools 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing GDAL library ... "

#======================================================================

yum --assumeyes install gdal-eox gdal-eox-python \
    gdal-eox-driver-dimap gdal-eox-driver-envisat \
    gdal-eox-driver-netcdf gdal-eox-driver-openjpeg2 \
    proj-epsg

