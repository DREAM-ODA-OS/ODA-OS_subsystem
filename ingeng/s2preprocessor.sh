#!/usr/bin/env sh
# 
#  DREAM Ingestion Engine: Invoke Sentinel-2 preprocessor.
#  This script is invoked by the Ingestion Engine
#  when the 'Sentinel-2 preprocessor' flag is set. 
#
# usage:
# $0 -targetdir=<download_directory> \
#    -outfile=<filename>     \
#    -meta=<metadatafile>    \
#    -beam_home=<path>
#
# targetdir: cd here before all processing
# meta  is the filename containing metadata, optional
# outfile is the output directory.
# beam_home is the full path to the BEAM installation dir.
#
# The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure.
#
#

script_name="s2_atm_pre_process"
opts="-f GEOTIFF"

date +"$script_name script started at "%c

if [[ $# < 3 ]]
then
    echo "Not enough args, exiting with status 1."
    exit 1
fi

for i in $*;
do
    case $i in
        -targetdir=* | -outfile=* | -meta=* | -beam_home=* | -) eval ${i:1};;
    esac
done

if [ ! -d $targetdir ]
then
    echo "$script_name: ($1) is not a dir, exiting."
    exit 2
fi

beam_home=${beam_home:-$BEAM_HOME}

cd $targetdir
tmp_gpt_sh=${beam_home}/bin/gpt.sh
if [ ! -x $tmp_gpt_sh ] ; then
    echo "$script_name: no executable gpt.sh found."
    echo "beam_home: $beam_home" 
    ex_status=3
else
    cmd_tmp="$tmp_gpt_sh C1-AtCorrProc -Ssource=$meta -t $outfile $opts"
    echo "running: $cmd_tmp"
    $cmd_tmp
    ex_status=$?
fi

date +"$script_name finishing with status $ex_status at "%c

exit $ex_status
