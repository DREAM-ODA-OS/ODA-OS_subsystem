#!/bin/sh
#
# get libgeotiff installed
#
. `dirname $0`/../lib_logging.sh

info "Installing GeoTIFF library and tools ..."

yum --assumeyes install libgeotiff

