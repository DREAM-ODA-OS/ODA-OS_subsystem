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

info "Catalogue metadata registration ..."

_manifest="`mktemp --suffix=.manifest`"
_rsp="`mktemp --suffix=.catreg`"
trap '_remove "$_tmp" "$_rsp" "$_manifest"' EXIT

if [ "$1" == '-' ]
then
    cat "$1" > "$_manifest"
    MANIFEST="$_manifest"
else
    MANIFEST="$1"
fi
cat $MANIFEST
[ -z "$MANIFEST" ] && { error "Missing the required manifest file!" ; exit 1 ; }
get_field() { sed -ne "s/^$1=\"\(.*\)\"/\1/p" "$MANIFEST" ;}
get_path() { get_field "$1" | _pipe_expand "$DIR" ;}

# get reference directory
DIR="`dirname "$MANIFEST"`"
DIR="`_expand "$DIR"`"

META="`get_path METADATA_EOP20`"
IDENTIFIER="`get_field IDENTIFIER`"
[ -n "$IDENTIFIER" ] || IDENTIFIER="`basename "$META".xml`"
_tmp="/tmp/$IDENTIFIER.xml"

#make sure the file is readable by the tomcat
cat "$META" > "$_tmp"

QUOTED="`python -c "from urllib import quote_plus; print quote_plus('$_tmp'),"`"

URL="http://127.0.0.1/excat2/csw?request=Harvest&service=CSW&version=2.0.2&namespace=xmlns(csw=http://www.opengis.net/cat/csw)&source=$QUOTED&resourceFormat=application/xml&resourceType=http://www.opengis.net/eop/2.0"

info "Registering product to the catalogue ..."
info "$URL"
curl -s -S $URL 2>&1 | tee "$_rsp" | info_pipe
_root="`xml_extract.py "$_rsp" './name()'`"
# check the response type
if [ '{http://www.opengis.net/ows/2.0}ExceptionReport' == "$_root" ]
then
    info "Removing the existing metadata record ..."
    "`dirname $0`/catalogue_deregister.sh" "$IDENTIFIER" || exit 1
    info "Second attempt ..."
    info "$URL"
    curl -s -S $URL 2>&1 | tee "$_rsp" | info_pipe
    _root="`xml_extract.py "$_rsp" './name()'`"
fi

if [ '{http://www.opengis.net/cat/csw/2.0.2}HarvestResponse' == "$_root" ]
then
    _nprod="`xml_extract.py "$_rsp" '//{http://www.opengis.net/cat/csw/2.0.2}totalInserted/text()'`"
    if [ "$_nprod" -eq "1" ]
    then
        info "Product metadata record inserted successfully into the catalogue."
        exit 0
    fi
fi

error "Failed to register the catalogue metadata record of product $IDENTIFIER!"
exit 1
