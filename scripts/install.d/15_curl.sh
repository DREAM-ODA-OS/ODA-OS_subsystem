#!/bin/sh
#
# get CURL installed
#
. `dirname $0`/../lib_logging.sh

info "Installing CURL ..."

yum --assumeyes install curl
