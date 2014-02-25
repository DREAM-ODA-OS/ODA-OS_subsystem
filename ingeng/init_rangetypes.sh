#!/usr/bin/env sh
# 
#  Initialize range-types 
#
#-----------------------------------------------------------------------------

MNG="/srv/odaos/eoxs00/manage.py"

DIR="`basename $0`"
DIR="`cd "$DIR" ; pwd`"

JSON="$DIR/range_types.json"

$MNG eoxs_rangetype_load < "$JSON"

