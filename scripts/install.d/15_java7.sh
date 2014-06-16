#!/bin/sh
#
# get Java7 installed
#
. `dirname $0`/../lib_logging.sh

info "Installing java7 JRE ..."

yum --assumeyes install java-1.7.0-openjdk

