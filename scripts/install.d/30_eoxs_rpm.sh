#!/bin/sh
#
# install EOxServer RPM 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing EOxServer ... "

#======================================================================

yum --assumeyes install EOxServer proj-epsg
