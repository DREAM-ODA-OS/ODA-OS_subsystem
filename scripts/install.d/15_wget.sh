#!/bin/sh
#
# get WGET installed
#
. `dirname $0`/../lib_logging.sh

info "Installing WGET ..."

yum --assumeyes install wget
