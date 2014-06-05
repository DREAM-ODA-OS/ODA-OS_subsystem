#!/bin/sh
#
#  Deregister product's metadata form a catalogue.
#
# USAGE: 
#  catalogue_deregister.sh <identifier> [TBC]
#
# DESCRIPTION: 
#  Deregister product metadata form a catalogue. The product
#  is specified by the provided identifier.
#
# NOTE: 
#  This script is not invoked directly by the Ingestion Engine.
#

. "`dirname $0`/lib_common.sh"

info "Catalogue metadata deregistration started ..."

if [ $# -lt 1 ]
then
    error "Not enough args, exiting with status 1."
    exit 1
fi

info "    IDENTIFIER: '$1'"

error "NOT IMPLEMENTED!" ; exit 1 
