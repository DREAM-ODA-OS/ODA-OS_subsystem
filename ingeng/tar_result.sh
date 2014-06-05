#!/usr/bin/env sh
# 
#  DREAM tar result script.
#  This script is invoked by the Ingestion Engine
#  when the 'tar results' flag is set.  The intent is 
#  is to package up in a tar file the complete result
#  of the ingestion, i.e. the ingested data with the
#   corresponding metadata files for off-line use.
#
# usage:
# $0 input_dir [-catreg=script]
#
# input_dir is the directory to be tarred.
#
# catreg is used to request registration in the local
#        metadata catalogue. The script arg is the name of
#        the script to be executed for cat registration.
#        If absent no registration should be done.
#
# The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure.
#
# The Ingestion Engine expects the resulting tar file to
#  be named 'input_dir.tgz'
#

script_name="tar_results"
echo "$script_name script started."

tar_command="tar"
tar_args="-czf"
tar_suffix=".tgz"

MANIFEST_FN="MANIFEST"

if [[ $# < 1 ]]
then
    echo "Not enough args, exiting with status 1."
    exit 1
fi

ex_status=0

dname=$(dirname $1)
bname=$(basename $1)

if [ ! -d $1 ] ; then
    echo 'dir $1 not accessible'
    exit 2
fi

if [ ! -d $dname ]
then
    echo 'dir $dname not accessible'
    exit 2
fi

cd $dname

tarfile=${bname}${tar_suffix}
cmd="$tar_command $tar_args  $tarfile $bname"

echo "starting cmd: $cmd"

$cmd

if [ $? -ne 0 ] 
then
    echo 'tar failed.'
    exit 3
fi

echo "$script_name: tar file is ready: ${dname}/$tarfile"

if [[ $2 == -catreg=* ]]
then
    echo $2
    echo "Ing. script: Catalogue registration requested."
    catregscript=${2:8}
    echo "catregscript: " $catregscript
    if [[ -f $catregscript ]] ; then
        echo "Ing. script: Running catalogue registration script in each product dir."
        cd $bname
        for uu in $(ls)
        do
            if [ ! -d $uu ] ; then continue ; fi
            echo "product dir: $uu"
            mffile=${uu}/${MANIFEST_FN}
            $catregscript $mffile
            cat_reg_status=$?
            echo 'cat. reg. script exited with ' $cat_reg_status
            if [ $cat_reg_status != 0 ] ; then ex_status=$cat_reg_status; fi
        done
    else
        echo "Ing. script: did not find an executable cat. reg. script ."
        ex_status=3
    fi
fi

echo "$script_name finishing with status " $ex_status
exit $ex_status
