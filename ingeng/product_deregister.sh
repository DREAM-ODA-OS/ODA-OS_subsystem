#!/usr/bin/env sh
#
#   Deregister single product from the ODA server.
#
# USAGE:
#   product_deregister.sh <product_id> [-catreg=<script>]
#
# DESCRIPTION:
#
#  Deregister a product without actual removal of the 
#  physical files.
#
# catreg is used to request de-registration of products
#        from the local metadata catalogue. The script
#        is the name of the script to be executed.
#        If absent no deregistration  should be done.
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure, and will
# prevent the product to be deleted.
#

. "`dirname $0`/lib_common.sh"

info " Product deregistration started ..."
info "   ARGUMENTS: $* "

# check and extract the inputs

IDENTIFIER=
CATREG=
for _arg in $*
do
    _key="`expr "$_arg" : '\([^=]*\)'`"
    _val="`expr "$_arg" : '[^=]*=\(.*\)'`"
    case "$_key" in
        '-catreg') CATREG="$_val" ;;
        *) IDENTIFIER="$_arg" ;;
    esac
done

[ -z "$IDENTIFIER" ] && { error "Missing the required product identifier!" ; exit 1 ; }
if [ -n "$CATREG" ]
then
    [ -f "$CATREG" ] || { error "The catalogue de-registration script does not exist! CATREG=$CATREG" ; exit 1 ; }
    [ -x "$CATREG" ] || { error "The catalogue de-registration script is not executable! CATREG=$CATREG" ; exit 1 ; }
fi

info "CATREG:  $CATREG"
info "IDENTIFIER:  $IDENTIFIER"

#-----------------------------------------------------------------------------
# optional catalogue de-registration

if [ -n "$CATREG" ]
then
    "$CATREG" "$IDENTIFIER" || warn "Catalogue deregistration failed!"
fi

#-----------------------------------------------------------------------------
# get WMS browse identifier

DATA="$IDENTIFIER"

TMP="`$EOXS_MNG eoxs_metadata_list -s 'wms_view' -i "$DATA" | grep wms_view | head -n 1`"
if [ -n "$TMP" ]
then
    eval TMPA=($TMP)
    VIEW="${TMPA[1]}"
fi

#-----------------------------------------------------------------------------
# deregister coverages

info "Deregistering dataset $DATA ..."
$EOXS_MNG eoxs_dataset_deregister "$DATA" || { error "Failed to deregister dataset $DATA!" ; exit 1 ; }
info "Deregistering dataset $VIEW ..."
[ -n "$VIEW" ] && { $EOXS_MNG eoxs_dataset_deregister "$VIEW" || { error "Failed to deregister dataset $VIEW!" ; exit 1 ; } }

#-----------------------------------------------------------------------------
# remove files
# ... skipped

#-----------------------------------------------------------------------------
# clean the id2path records

info "Cleaning the Id2Path records ..."
{
    $EOXS_MNG eoxs_i2p_list --unbound --full -i "$DATA"
    [ -n "$VIEW" ] && $EOXS_MNG eoxs_i2p_list --unbound --full -i "$VIEW"
} | $EOXS_MNG eoxs_i2p_delete || { error "Id2Path deregistration failed!" ; exit 1 ; }

info "Product deregistration finished sucessfully."
