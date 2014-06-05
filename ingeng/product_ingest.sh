#!/usr/bin/env sh
#
#  DREAM Ingestion script template.
#  This script is invoked by the Ingestion Engine
#  to ingest a downloaded product into the ODA server.
#
# usage:
# $0 manifest-file [-catreg=script]
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure.
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
# load common definitions
. lib_common.sh

#-----------------------------------------------------------------------------

drop() { echo "DEMO: dropping product ingestion: $1" ; exit 0 ; }

#-----------------------------------------------------------------------------

info "ODA-Server ingestion ... "

[ $# -lt 1 ] && { error "Missing the required manifest file!" ; exit 1 ; }
[ -f "$1" ] || { error "The manifest file does not exist! MANIFEST=$1" ; exit 1 ; }

MANIFEST=$1
echo "MANIFEST:  $MANIFEST"

#-----------------------------------------------------------------------------
# parse manifest

DATA="`cat "$MANIFEST" | sed -ne 's/^DATA="\(.*\)"/\1/p'`"
COVDESCR="`cat "$MANIFEST" | sed -ne 's/^METADATA="\(.*\)"/\1/p'`"
SCENARIO="`cat "$MANIFEST" | sed -ne 's/^SCENARIO_NCN_ID="\(.*\)"/\1/p'`"
METADATA="`expr "$DATA" : '\(.*\)\.[a-zA_Z]*'`.xml"

EOP20="http://www.opengis.net/eop/2.0"

# extract the metadata profile
xml_extract.py "$COVDESCR" "//{$EOP20}EarthObservation" PRETTY > "$METADATA"

# extract product type
ID="`xml_extract.py "$METADATA" "//{$EOP20}identifier" TEXT`"
PFORM="`xml_extract.py "$METADATA" "//{$EOP20}Platform/{$EOP20}shortName" TEXT`"
PTYPE="`xml_extract.py "$METADATA" "//{$EOP20}productType" TEXT`"


echo "ID:        $ID"
echo "PLATFORM:  $PFORM"
echo "PROD.TYPE: $PTYPE"

#-----------------------------------------------------------------------------
# get range-type
#
#  RGBA
#  Mask_uint8
#  Mask_uint16
#  SimS2_LandsatTM_uint8
#  SPOT4HRVIR_int16
#  Landsat5TM_int16
#  Landsat7ETM_int16
#

if [ "${PTYPE:0:10}" = "Spot4Take5" ]
then
    # SPOT4-TAKE5
    T="`expr "$ID" : ".*\(N[12][AC].*\)"`"

    case "$T" in
        N1C | N2A_PENTE | N2A_ENV )     drop "$ID" ; RANGE="SPOT4HRVIR_int16" ;;
        N1C_RGB )                       drop "$ID" ; RANGE="RGBA" ;;
        N2A_RGB )                       RANGE="RGBA" ;;
        N1C_SAT | N2A_SAT | N2A_DIV )   drop "$ID" ; RANGE="Mask_uint8" ;;
        N2A_AOT | N2A_NUA )             drop "$ID" ; RANGE="Mask_int16" ;;
        * ) error "Unknown product range type!" ; exit 1 ;;
    esac

elif [ "$PFORM" == "LANDSAT" -a "${ID:0:5}" == "S2sim" ]
then
    # GISAT - LANDSAT S2-SIM

    case "$PTYPE" in
        L1C_rad )           drop "$ID" ; RANGE="SimS2_LandsatTM_uint8" ;;
        L1C_cm )            drop "$ID" ; RANGE="Mask_uint8" ;;
        L1C_rgb_wgs84 )     RANGE="RGBA" ;;
        * ) error "Unknown product range type!" ; exit 1 ;;
    esac

elif [ \( "$PFORM" == "LANDSAT5" -o  "$PFORM" == "LANDSAT7" \) -a "${ID:0:1}" == "L" \
    -a \( "${ID:28:18}" == "ESA_surf_pente_30m" -o "${ID:28:19}" == "USGS_surf_pente_30m" \) ]
then
    # CESBIO Landsat Dataset

    if [ "$ID" != "${ID//_surf_pente_30m/}" ]
    then
        case "$PFORM" in
            "LANDSAT5" ) RANGE="Landsat5TM_int16" ;;
            "LANDSAT7" ) RANGE="Landsat7ETM_int16" ;;
            * ) error "Unknown product range type!" ; exit 1 ;;
        esac

    elif [ "$ID" != "${ID//RGB_WSG84/}" ]
    then
        RANGE="RGBA"
    else
        error "Unknown product range type!" ; exit 1
    fi

    # fix the metadata
    sed -e 's/\(<gml:beginPosition>\)\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\(<\/gml:beginPosition>\)/\1\2Z\3/' \
        -e 's/\(<gml:endPosition>\)\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\(<\/gml:endPosition>\)/\1\2Z\3/' \
        -i "$METADATA"

else

    error "Unknown product!"
    exit 1

fi

echo "RANGE TYPE: $RANGE"


#-----------------------------------------------------------------------------
# registration

set -e

# refuse register already registered coverages


# create scenario data-set
if $EOXS_MNG eoxs_eoid_check -i "$SCENARIO" -f DatasetSeries
then
    # everyhting is fine - do nothing
    echo -n
else
    $EOXS_MNG eoxs_series_create -i "$SCENARIO"
fi

# register dataset
if $EOXS_MNG eoxs_eoid_check -i "$ID" -f Coverage
then
    warn "There is already a coverage registered under the same ID."
    $EOXS_MNG eoxs_series_link -s "$SCENARIO" -a "$ID"
else
    $EOXS_MNG eoxs_dataset_register -i "$ID" -r "$RANGE" -d "$DATA" -m "$METADATA" --series "$SCENARIO"
fi

#-----------------------------------------------------------------------------

# fix the screwed permissions
chmod -R +r /srv/tmp/ngeo-dm/
find /srv/tmp/ngeo-dm/ -type d -exec chmod +x {} \;


info "ODA-Server ingestion finished successfully."

#-----------------------------------------------------------------------------

#echo "Default Ingestion script started."
#
#if [[ $# < 1 ]]
#then
#    echo "Not enough args, exiting with status 1."
#    exit 1
#fi
#
#ex_status=0
#
#echo arg: $1
#echo "arg1 contains:"
#cat $1
#
#if [[ $2 == -catreg=* ]]
#then
#    echo $2
#    echo "Ing. script: Catalogue registration requested."
#    catregscript=${2:8}
#    echo "catregscript: " $catregscript
#    if [[ -f $catregscript ]] ; then
#        echo "Ing. script: Running catalogue registration script."
#        $catregscript $1
#        cat_reg_status=$?
#        echo 'cat. reg. script exited with ' $cat_reg_status
#        if [ $cat_reg_status != 0 ] ; then ex_status=$cat_reg_status; fi
#    else
#        echo "Ing. script: did not find an executable cat. reg. script ."
#        ex_status=3
#    fi
#fi
#
##-----------------------------------------------------------------------------
## parse manifest file
#
#echo "---"
#echo " WARNING: Ingestion action not yet implemented!"
#echo "---"
#
##-----------------------------------------------------------------------------
#
#
#echo "Default Ingestion script finishing with status " $ex_status
#exit $ex_status
