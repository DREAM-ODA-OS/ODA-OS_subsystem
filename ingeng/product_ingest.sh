#!/usr/bin/env sh
#
#  INgest product to the ODA server.
#
# USAGE:
#   product_ingest.sh <manifest-file> [-catreg=<script>]
#
# DESCRIPTION:
#
#  The script should exit with a 0 status to indicate
#  success; a non-zero status indicates failure.
#
# catreg is used to request registration in the local
#        metadata catalogue. The script is the name of
#        the script to be executed for cat registration.
#        If absent no registration should be done.
#
# The manifest file is further input to this script,
# and contains KV pairs.  Values are strings enclosed
# in quotes. Here are examples of the most important
# KV pairs contained in the manifest file:
#
#    SCENARIO_NCN_ID="scid0"
#    DOWNLOAD_DIR="/path/p_scid0_001"
#    METADATA="/path/p_scid0_001/ows.meta"
#    DATA="/path/p_scid0_001/p1.tif"
#
#
#-----------------------------------------------------------------------------

. "`dirname $0`/lib_common.sh"

info "ODA-Server product ingestion started ..."
info "   ARGUMENTS: $* "

# check and extract the inputs

MANIFEST=
CATREG=
for _arg in $*
do
    _key="`expr "$_arg" : '\([^=]*\)'`"
    _val="`expr "$_arg" : '[^=]*=\(.*\)'`"
    case "$_key" in
        '-catreg') CATREG="$_val" ;;
        *) MANIFEST="$_arg" ;;
    esac
done

[ -z "$MANIFEST" ] && { error "Missing the required manifest file!" ; exit 1 ; }
[ -f "$MANIFEST" ] || { error "The manifest file does not exist! MANIFEST=$MANIFEST" ; exit 1 ; }
if [ -n "$CATREG" ]
then
    [ -f "$CATREG" ] || { error "The catalogue registration script does not exist! CATREG=$CATREG" ; exit 1 ; }
    [ -x "$CATREG" ] || { error "The catalogue registration script is not executable! CATREG=$CATREG" ; exit 1 ; }
fi

info "CATREG:  $CATREG"
info "MANIFEST:  $MANIFEST"

#-----------------------------------------------------------------------------
# parse manifest and prepare the metadata

DATA="`cat "$MANIFEST" | sed -ne 's/^DATA="\(.*\)"/\1/p'`"
VIEW="`cat "$MANIFEST" | sed -ne 's/^VIEW="\(.*\)"/\1/p'`"
COVDESCR="`cat "$MANIFEST" | sed -ne 's/^METADATA="\(.*\)"/\1/p'`"
COLLECTION="`cat "$MANIFEST" | sed -ne 's/^SCENARIO_NCN_ID="\(.*\)"/\1/p'`"
DATADIR="`cat "$MANIFEST" | sed -ne 's/^DOWNLOAD_DIR="\(.*\)"/\1/p'`"
META="`cat "$MANIFEST" | sed -ne 's/^METADATA_EOP20="\(.*\)"/\1/p'`"
RANGET="`cat "$MANIFEST" | sed -ne 's/^RANGE_TYPE="\(.*\)"/\1/p'`"
IDENTIFIER="`cat "$MANIFEST" | sed -ne 's/^IDENTIFIER="\(.*\)"/\1/p'`"

[ -n "$META" ] || META="`expr "$DATA" : '\(.*\)\.[a-zA_Z]*'`.xml"
[ -n "$RANGET" ] || RANGET="`expr "$DATA" : '\(.*\)\.[a-zA_Z]*'`_range_type.json"
[ -n "$VIEW" ] || VIEW="`expr "$DATA" : '\(.*\)\.[a-zA_Z]*'`_view.tif"
[ -n "$VIEW_OVR" ] || VIEW_OVR="`expr "$DATA" : '\(.*\)\.[a-zA_Z]*'`_view.tif.ovr"

EOP_VER="2.0"
EOP="http://www.opengis.net/eop/$EOP_VER"
OPT="http://www.opengis.net/opt/$EOP_VER"
SAR="http://www.opengis.net/opt/$EOP_VER"

if [ ! -f "$META" ]
then
    # extract the metadata profile
    for NS in $EOP $OPT $SAR
    do
        xml_extract.py "$COVDESCR" "//{$NS}EarthObservation" PRETTY > "$META" && break || _remove "$META"
    done
    # fix the metadata if needed
    sed -e 's/\(<gml:beginPosition>\)\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\(<\/gml:beginPosition>\)/\1\2Z\3/' \
        -e 's/\(<gml:endPosition>\)\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\(<\/gml:endPosition>\)/\1\2Z\3/' \
        -i "$META"
fi
[ -f "$META" ] || { error "Failed to extract the EOP metadata from $COVDESCR!" ; exit 1 ; }

# extract coverage identifier
[ -n "$IDENTIFIER" ] || IDENTIFIER="`xml_extract.py "$META" //{$EOP}identifier TEXT`"
[ -n "$IDENTIFIER" ] || { error "Failed to extract the IDENTIFIER from $META!" ; exit 1 ; }

# extract range-type
if [ ! -f "$RANGET" ]
then
    gmlcov2rangetype.py "$COVDESCR" "$DATA" "$IDENTIFIER" > "$RANGET" || _remove "$RANGET"
fi
[ -f "$RANGET" ] || { error "Failed to extract the RangeType metadata from $COVDESCR!" ; exit 1 ; }

# prepare automatic RGB preview if needed
if [ `jq '.bands|length' "$RANGET"` -lt 3 ]
then # grayscale preview
    _type="MINISBLACK"
    _bands="-b 1"
else # RGB preview
    _type="RGB"
    _bands="-b 1 -b 2 -b 3"
fi
if [ ! -f "$VIEW" ]
then
    info "Generating browse image ..."
    _tmp0="`mktemp`.tif"
    _tmp1="`mktemp`.tif"
    trap "_remove '$_tmp0' '$_tmp1'" EXIT
    info "... band extraction ..."
    _remove "$_tmp0"
    time gdal_translate $_bands "$DATA" "$_tmp0" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
    info "... warping ..."
    _remove "$_tmp1"
    time gdalwarp -t_srs "EPSG:4326" $WOPT -srcnodata 0 -dstnodata 0 "$_tmp0" "$_tmp1" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
    _remove "$_tmp0"
    info "... range-stretch ..."
    range_stretch.py "$_tmp1" "$VIEW" 2 255 0 ADDALPHA `echo $TOPT | sed -e 's/-co//g'` "PHOTOMETRIC=$_type" || exit 1
    _remove "$_tmp1"
    _remove "$VIEW_OVR"
    # clip the view image removing the empty area
    info "... subset extraction ..."
    extract_mask.py "$VIEW" "$_tmp0" 0
    SUBSET="`find_subset.py "$_tmp0" 0`"
    [ 0 -eq "`python -c "v=[$SUBSET];print v[2]*v[3];"`" ] && SUBSET="0,0,1,1"
    _remove "$_tmp0"
    info "SUBSET: $SUBSET"
    extract_subset.py "$VIEW" "$_tmp1" "$SUBSET" `echo $TOPT | sed -e 's/-co//g'` "PHOTOMETRIC=$_type"
    mv "$_tmp1" "$VIEW"
    trap - EXIT
fi
[ -f "$VIEW" ] || { error "Failed to generate the browse image!" ; exit 1 ; }

# generate overviews
if [ ! -f "$VIEW_OVR" ]
then
    info "... generating browse overviews ..."
    _levels="`get_gdaladdo_levels.py "$VIEW" 32 8`"
    _adoopt="$ADOOPT --config PHOTOMETRIC_OVERVIEW $_type -ro"
    _remove "$VIEW_OVR"
    [ -n "$_levels" ] && time "$GDALADDO" $_adoopt "$VIEW" $_levels
fi

# append EOP2.0 metadata and range-type to the manifest
ex "$MANIFEST" <<END
1,\$g/^METADATA_EOP20=/d
1,\$g/^RANGE_TYPE=/d
1,\$g/^IDENTIFIER=/d
1,\$g/^VIEW=/d
1,\$g/^VIEW_OVR=/d
\$a
VIEW="$VIEW"
VIEW_OVR="$VIEW_OVR"
METADATA_EOP20="$META"
RANGE_TYPE="$RANGET"
IDENTIFIER="$IDENTIFIER"
.
wq
END

# log the content of the manifest file
cat "$MANIFEST" | while read L
do
    info "MANIFEST: $L"
done

#-----------------------------------------------------------------------------
# register dataset

DATA_RANGE_TYPE="`jq -r '.["name"]' "$RANGET" `"
[ -n "$DATA_RANGE_TYPE" ] || { error "Failed to detect the data range-type!" ; exit 1 ; }
_NBANDS="`python -c "from osgeo import gdal; print gdal.Open('$VIEW').RasterCount;"`"
[ $_NBANDS -eq 1 ] && VIEW_RANGE_TYPE="Grayscale"
[ $_NBANDS -eq 2 ] && VIEW_RANGE_TYPE="GrayAlpha"
[ $_NBANDS -eq 3 ] && VIEW_RANGE_TYPE="RGB"
[ $_NBANDS -eq 4 ] && VIEW_RANGE_TYPE="RGBA"
[ -n "$VIEW_RANGE_TYPE" ] || { error "Failed to detect the browse range-type!" ; exit 1 ; }

#create time-series
if $EOXS_MNG eoxs_id_check --type DatasetSeries "$COLLECTION"
then
    $EOXS_MNG eoxs_collection_create --type DatasetSeries -i "$COLLECTION"
    $EOXS_MNG eoxs_metadata_set -i "$COLLECTION" -s 'wms_view' -l "${COLLECTION}_view"
    $EOXS_MNG eoxc_layer_create -i "$COLLECTION" --time
fi

if $EOXS_MNG eoxs_id_check --type DatasetSeries "${COLLECTION}_view"
then
    $EOXS_MNG eoxs_collection_create --type DatasetSeries -i "${COLLECTION}_view"
    $EOXS_MNG eoxs_metadata_set -i "${COLLECTION}_view" -s 'wms_alias' -l "$COLLECTION"
fi

# load range-type
$EOXS_MNG eoxs_rangetype_load -i "$RANGET"

# register the data and view
#TODO: fix coverage removal
$EOXS_MNG eoxs_id_check --type Coverage "$IDENTIFIER" || $EOXS_MNG eoxs_dataset_deregister "$IDENTIFIER"
$EOXS_MNG eoxs_id_check --type Coverage "${IDENTIFIER}_view" || $EOXS_MNG eoxs_dataset_deregister "${IDENTIFIER}_view"
$EOXS_MNG eoxs_dataset_register -r "$DATA_RANGE_TYPE" -i "${IDENTIFIER}" \
    -d "$DATA" -m "$META" --collection "$COLLECTION" \
    --view "${IDENTIFIER}_view" $DATE_REG_OPT
$EOXS_MNG eoxs_dataset_register -r "$VIEW_RANGE_TYPE" -i "${IDENTIFIER}_view" \
    -d "$VIEW" -m "$META" --collection "${COLLECTION}_view" \
    --alias "$COLLECTION"
# id2path file registry
{
    echo "#$IDENTIFIER"
    echo "$DATADIR;directory"
    echo "$DATA;data"
    echo "$META;metadata;EOP2.0"
    echo "$RANGET;file;range-type"
    echo "$COVDESCR;file;gmlcov"
    echo "#${IDENTIFIER}_view"
    echo "$DATADIR;directory"
    echo "$VIEW;data;browse"
    echo "$VIEW_OVR;file;overviews"
    echo "$META;metadata;EOP2.0"
} | $EOXS_MNG eoxs_i2p_load

info "Product ingestion finished sucessfully."

#-----------------------------------------------------------------------------
# optional catalogue registration
# TODO: filling the other metadata

if [ -n "$CATREG" ]
then
    "$CATREG" "$MANIFEST" || exit 1
fi
