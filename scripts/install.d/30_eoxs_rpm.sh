#!/bin/sh
#
# install EOxServer RPM 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

#info "Installing EOxServer ... "
info "Installing EOxServer Dependencies ... "
# NOTE: as long as there is on 0.4 RPM on-line we go for 
#       manual EOxServer install. We need the dependencies 
#       though 

#======================================================================

#yum --assumeyes install EOxServer proj-epsg
yum --assumeyes install proj-epsg fcgi gd libXpm libxml2-python mapserver mapserver-python
