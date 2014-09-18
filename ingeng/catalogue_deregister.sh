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

ID=$1
[ -z "$ID" ] && { error "Missing the required product identifier!" ; exit 1 ; }

info "    IDENTIFIER: '$ID'"

QUOTED="`python -c "from urllib import quote_plus; print quote_plus('$ID'),"`"

URL="http://127.0.0.1/excat2/csw?request=Transaction&service=CSW&version=2.0.2&namespace=xmlns(csw=http://www.opengis.net/cat/csw/2.0.2)&transactiontype=delete&constraint=apeop:identifier=%27$QUOTED%27&constraintLanguage=CQL_TEXT&constraint_language_version1.1.0&typeName=eop:EarthObservation"

info "Deregistering product ..."
info "$URL"
curl -s -S $URL 2>&1 | while read L
do
    info "$L"
done
