#!/bin/sh
#
# install the unzip tool
#

. `dirname $0`/../lib_logging.sh

info "Installing unzip ..."

yum --assumeyes install unzip
