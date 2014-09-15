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
 
MANIFEST=$1
[ -z "$MANIFEST" ] && { error "Missing the required manifest file!" ; exit 1 ; }

# get reference directory
DIR="`dirname "$MANIFEST"`"
DIR="`_expand "$DIR"`"

META="`cat "$MANIFEST" | sed -ne 's/^METADATA_EOP20="\(.*\)"/\1/p' | _pipe_expand "$DIR"`"
QUOTED="`python -c "from urllib import quote_plus; print quote_plus('$META'),"`"

URL="http://localhost/excat2/csw?request=Harvest&service=CSW&version=2.0.2&namespace=xmlns(csw=http://www.opengis.net/cat/csw)&source=$QUOTED&resourceFormat=application/xml&resourceType=http://www.opengis.net/eop/2.0"

info "Registering product ... URL='$URL'"
curl --verbose $URL
