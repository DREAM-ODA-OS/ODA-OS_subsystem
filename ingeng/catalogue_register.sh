#!/bin/sh
#
#  Register product's metadata to a catalogue.
#
# USAGE: 
#  catalogue_deregister.sh <manifest> [TBC]
#
# DESCRIPTION: 
#  Register product's metadata form a catalogue. 
#  The inputs are passed via the manifest file.
#
#  The manifest file contains KV pairs.  
#  Values are strings enclosed in quotes.
#  Here are examples of the most important
#  KV pairs contained in the manifest file:
#
#    SCENARIO_NCN_ID="scid0"
#    DOWNLOAD_DIR="/path/p_scid0_001"
#    METADATA="/path/p_scid0_001/ows.meta"
#    DATA="/path/p_scid0_001/p1.tif"
#
# NOTE: 
#  This script is not invoked directly by the Ingestion Engine.
#

. "`dirname $0`/lib_common.sh"

info "Catalogue metadata registration started ..."

if [ $# -lt 1 ]
then
    error "Not enough args, exiting with status 1."
    exit 1
fi

info "    MANIFEST: '$1'"

error "NOT IMPLEMENTED!" ; exit 1 
