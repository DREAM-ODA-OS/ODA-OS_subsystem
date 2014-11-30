#!/usr/bin/env bash
#
#  DREAM Update MetaData script template.
#  This script is invoked by the Ingestion Engine
#  during the operation updateMD on the interface
#   IF-DREAM-O-UpdateQualityMD
#
# usage:
# $0   [ -add | -replace ]  <ProductID>  <metadatafile>
#
#  metadatafile is a full pathname.
#
# The script should exit with status 0 if all went well
# and non-zero otherwise.  The expected range of error
# codes is 1-9.
#

. "`dirname $0`/lib_common.sh"

info "Metadata update started ..."
info "PARAMS: $*"

# parse the CLI arguments
DIR="."

for _arg in $*
do
    _key="`expr "$_arg" : '\([^=]*\)'`"
    _val="`expr "$_arg" : '[^=]*=\(.*\)'`"

    case "$_key" in
        '-add' )
            REPLACE="" ;;
        '-replace' )
            REPLACE="REPLACE" ;;
        *)
            if [ -z "$IDENTIFIER" ]
            then
                IDENTIFIER="$_arg"
            elif [ -z "$META_DQ" ]
            then
                META_DQ="$_arg"
            fi
    esac
done

[ -z "$IDENTIFIER" ] && { error "Missing the required dataset identifier!" ; exit 1 ; }
[ -z "$META_DQ" ] && { error "Missing the required DQ metadata!" ; exit 1 ; }
[ ! -f "$META_DQ" ] && { error "The DQ metadata file does not exist! META_DQ=$META_DQ" ; exit 1 ; }

info "REPLACE:  $REPLACE"
info "IDENTIFIER:  $IDENTIFIER"
info "META_DQ:  $META_DQ"

info "Getting location of the EOP metadata file ..."
META_EOP="`$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER" | grep '^[^;]*;metadata;EOP2.0' | head -n 1 | cut -f 1 -d ';'`"
info "META_EOP:  $META_EOP"
[ -z "$META_EOP" ] && { error "Failed to locate the EOP metadata for dataset '$IDENTIFIER' !" ; exit 1 ; }
[ ! -f "$META_EOP" ] && { error "The EOP metadata file does not exist! META_EOP=$META_EOP" ; exit 1 ; }

info "Updating the EOP metadata ..."
_tmp0="`mktemp --suffix=.xml`"
trap "_remove '$_tmp0'" EXIT
"`dirname $0`/insert_dq_into_eop.py" "$META_EOP" "$META_DQ" PRETTY $REPLACE > "$_tmp0" && mv "$_tmp0" "$META_EOP" || exit 1

info "Metadata update finished sucessfully."
