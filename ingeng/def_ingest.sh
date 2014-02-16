#!/usr/bin/env sh
# 
#  DREAM Ingestion script template.
#  This script is invoked by the Ingestion Engine
#  to ingest a downloaded product into the ODA server.
#
# usage:
# $0 manifest-file [-catreg=script]
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure.
#
# catreg is used to request registration in the local
#        metadata catalogue. The script is the name of
#        the script to be executed for cat registration.
#        If absent no registration should be done.
#
# The manifest file is further input to this script,
# and contains KV pairs.  Values are strings enclosed
# in quotes. Here are examples of the most important
# KV pairs contained in the manifest file:
#
#    SCENARIO_NCN_ID="scid0"
#    DOWNLOAD_DIR="/path/p_scid0_001"
#    METADATA="/path/p_scid0_001/ows.meta"
#    DATA="/path/p_scid0_001/p1.tif"
#
#

echo "Default Ingestion script started."

if [[ $# < 1 ]]
then
    echo "Not enough args, exiting with status 1."
    exit 1
fi

ex_status=0

echo arg: $1
echo "arg1 contains:"
cat $1

if [[ $2 == -catreg=* ]]
then
    echo $2
    echo "Ing. script: Catalogue registration requested."
    catregscript=${2:8}
    echo "catregscript: " $catregscript
    if [[ -f $catregscript ]] ; then
        echo "Ing. script: Running catalogue registration script."
        $catregscript $1
        cat_reg_status=$?
        echo 'cat. reg. script exited with ' $cat_reg_status
        if [ $cat_reg_status != 0 ] ; then ex_status=$cat_reg_status; fi
    else
        echo "Ing. script: did not find an executable cat. reg. script ."
        ex_status=3
    fi
fi

echo "Default Ingestion script finishing with status " $ex_status
exit $ex_status
