#!/usr/bin/env sh
# 
#  DREAM Local Catalogue registration script template.
#  This script is invoked by the igestion script.
#  Note, it is not invoked directly by the Ingestion Engine.
#
# usage:
# $0 manifest-file
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure.
#
# The manifest file contains KV pairs.  
# Values are strings enclosed in quotes.
# Here are examples of the most important
# KV pairs contained in the manifest file:
#
#    SCENARIO_NCN_ID="scid0"
#    DOWNLOAD_DIR="/path/p_scid0_001"
#    METADATA="/path/p_scid0_001/ows.meta"
#    DATA="/path/p_scid0_001/p1.tif"
#
#

echo "Default Local Catalogue registration script started."

if [[ $# < 1 ]]
then
    echo "Not enough args, exiting with status 1."
    exit 1
fi

echo arg: $1
echo "arg1 contains:"
cat $1

echo "Default Local Cat registration script finishing with status 0."
exit 0
