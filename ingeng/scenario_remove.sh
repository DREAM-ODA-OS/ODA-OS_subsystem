#!/usr/bin/env sh
#
#   Remove product from the ODA server.
#
# USAGE:
#   product_remove.sh <nc_id> [-catreg=<script>]
#
# DESCRIPTION:
#
#  DREAM Delete script template.
#  This script is invoked by the Ingestion Engine
#  when a scenario is deleted.
#  It is expected that the script will de-register
#  products associated with the scenario, and delete the
#  corresponding physical files on the disc (filesystem).
#
# catreg is used to request de-registration of products
#        from the local metadata catalogue. The script
#        is the name of the script to be executed.
#        If absent no deregistration  should be done.
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure, and will
# prevent the scenario to be deleted from the Ingestion
# Engine's list of scenarios.
#

. "`dirname $0`/lib_common.sh"

info " Scenario removal started ..."
info "   ARGUMENTS: $* "

REMOVE="`dirname $0`/product_remove.sh"

# check and extract the inputs

COLLECTION=
CATREG=
for _arg in $*
do
    _key="`expr "$_arg" : '\([^=]*\)'`"
    _val="`expr "$_arg" : '[^=]*=\(.*\)'`"
    case "$_key" in
        '-catreg') CATREG="$_val" ;;
        *) COLLECTION="$_arg" ;;
    esac
done

[ -z "$COLLECTION" ] && { error "Missing the required scenario (collection) name!" ; exit 1 ; }
if [ -n "$CATREG" ]
then
    [ -f "$CATREG" ] || { error "The catalogue de-registration script does not exist! CATREG=$CATREG" ; exit 1 ; }
    [ -x "$CATREG" ] || { error "The catalogue de-registration script is not executable! CATREG=$CATREG" ; exit 1 ; }
fi

info "CATREG:  $CATREG"
info "COLLECTION:  $COLLECTION"
[ -n "$CATREG" ] && CATREG="-catreg=$CATREG"

#-----------------------------------------------------------------------------
# check collection identifier

# NOTE: invalid collection name is interpreted as an empty collection
$EOXS_MNG eoxs_id_check --type DatasetSeries "$COLLECTION" && { warn "Collection $COLLECTION does not exist!" ; exit 0 ; }

#-----------------------------------------------------------------------------
# remove coverages
$EOXS_MNG eoxs_id_list -r --type DatasetSeries "$COLLECTION" | sed -e 's/^\s*//' -e 's/\s\+/ /g' | while read ITEM
do
    C_ID="`echo "$ITEM" | cut -d ' ' -f 1 `"
    C_TYPE="`echo "$ITEM" | cut -d ' ' -f 2 `"

    case $C_TYPE in
        RectifiedDataset | ReferenceableDataset )
            $REMOVE "$C_ID" $CATREG
            ;;
    esac
done

#-----------------------------------------------------------------------------
# get WMS browse collection identifier

DATA="$COLLECTION"

TMP="`$EOXS_MNG eoxs_metadata_list -s 'wms_view' -i "$DATA" | grep wms_view | head -n 1`"
if [ -n "$TMP" ]
then
    eval TMPA=($TMP)
    VIEW="${TMPA[1]}"
fi
#-----------------------------------------------------------------------------
# remove the client layer

$EOXS_MNG eoxc_layer_delete -i "$DATA" || { error "Failed to remove client layer $DATA!" ; exit 1 ; }

#-----------------------------------------------------------------------------
# remove the dataset series

$EOXS_MNG eoxs_collection_delete -r -i "$DATA" || { error "Failed to remove collection $DATA!" ; exit 1 ; }
[ -n "$VIEW" ] && { $EOXS_MNG eoxs_collection_delete -r -i "$VIEW" || { error "Failed to remove collection $VIEW!" ; exit 1 ; } }

#-----------------------------------------------------------------------------
# remove files
#{
#    $EOXS_MNG eoxs_i2p_list --unbound-strict --full -i "$DATA" || { error "Id2Path list failed for $DATA!" ; exit 1 ; }
#    [ -n "$VIEW" ] && { $EOXS_MNG eoxs_i2p_list --unbound-strict --full -i "$VIEW" || { error "Id2Path list failed for $VIEW!" ; exit 1 ; } }
#} | grep -v "^#" | sed -s 's/;.*$//' | while read F
#do
#    rm -vfR "$F"
#done

#-----------------------------------------------------------------------------
# clean the id2path records
#{
#    $EOXS_MNG eoxs_i2p_list --unbound --full -i "$DATA"
#    [ -n "$VIEW" ] && $EOXS_MNG eoxs_i2p_list --unbound --full -i "$VIEW"
#} | $EOXS_MNG eoxs_i2p_delete || { error "Id2Path deregistration failed!" ; exit 1 ; }

info " Scenario removal finished sucessfully."
