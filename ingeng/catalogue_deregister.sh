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

_rsp="`mktemp --suffix=.catreg`"
trap "_remove '$_rsp'" EXIT

info "Catalogue metadata deregistration started ..."

IDENTIFIER=$1
[ -z "$IDENTIFIER" ] && { error "Missing the required product identifier!" ; exit 1 ; }

info "    IDENTIFIER: '$IDENTIFIER'"

QUOTED="`python -c "from urllib import quote_plus; print quote_plus('$IDENTIFIER'),"`"

URL="http://127.0.0.1/excat2/csw?request=Transaction&service=CSW&version=2.0.2&namespace=xmlns(csw=http://www.opengis.net/cat/csw/2.0.2)&transactiontype=delete&constraint=apeop:identifier=%27$QUOTED%27&constraintLanguage=CQL_TEXT&constraint_language_version1.1.0&typeName=eop:EarthObservation"

info "Deregistering product ..."
info "$URL"
curl -s -S $URL 2>&1 | tee "$_rsp" | info_pipe
_root="`xml_extract.py "$_rsp" './name()'`"

if [ '{http://www.opengis.net/cat/csw/2.0.2}TransactionResponse' == "$_root" ]
then
    _nprod="`xml_extract.py "$_rsp" '//{http://www.opengis.net/cat/csw/2.0.2}totalDeleted/text()'`"
    if [ "$_nprod" -eq "1" ]
    then
        info "Product metadata record removed successfully from the catalogue."
        exit 0
    elif [ "$_nprod" -eq "0" ]
    then
        warn "No metadata record removed!"
        warn "There is no metadata record of product $IDENTIFIER registered to the catalogue!"
        exit 0
    fi
fi

error "Failed to deregister the catalogue metadata record of product $IDENTIFIER!"
exit 1
