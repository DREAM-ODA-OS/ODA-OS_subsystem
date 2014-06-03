#!/usr/bin/env sh
#
#  Initialize range-types
#
#-----------------------------------------------------------------------------
# load common definitions
. lib_common.sh

#-----------------------------------------------------------------------------

DIR="`basename $0`"
DIR="`cd "$DIR" ; pwd`"

JSON="$DIR/range_types.json"

$EOXS_MNG eoxs_rangetype_load < "$JSON"

