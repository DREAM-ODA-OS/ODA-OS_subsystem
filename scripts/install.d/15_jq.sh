#!/bin/sh
#
# get ./jq installed 
#
. `dirname $0`/../lib_logging.sh  

info "Installing JQ ..."

yum --assumeyes install jq 

