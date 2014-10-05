#!/bin/bash
#------------------------------------------------------------------------------
#
# product type detection library
#
# Project: Image Processing Tools
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2014 EOX IT Services GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies of this Software or works derived from this Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

function _one_line_only()
{
    _cnt=0
    while read L
    do
        [ "$_cnt" -gt 0 ] && { error "$1" ; exit 1 ; }
        echo "$L"
        _cnt=1
    done
}

#-------------------------------------------------------------------------------
# try to locate the metadata files if not provided
_msg="Multiple metadata files found! Cannot unambiguosly detect the metadata file!"
if [ -z "$META" -a -d "$DATA" ] # no-metadata - data as directory
then
    # look-up for the SPOT and Pleiades metadata
    [ -z "$META" ] && META="`find "$DATA" -name METADATA.DIM | _one_line_only "$_msg"`"
    [ -z "$META" ] && META="`find "$DATA" -name metadata.dim | _one_line_only "$_msg"`"
    [ -z "$META" ] && META="`find "$DATA" -name DIM_\*.XML | _one_line_only "$_msg"`"
    [ -z "$META" ] && META="`find "$DATA" -name \*.dim | _one_line_only "$_msg"`"
elif [ -z "$META" -a -f "$DATA" ] # no-metadata - data as a file (image)
then
    # EOP metadata
    [ -f "${DATA%.*}.xml" ] && META="${DATA%.*}.xml"
    [ -f "${DATA%.*}.XML" ] && META="${DATA%.*}.XML"
    # Envisat N1 and similar
    [ -n "`head -n 1 "$DATA" | sed -ne '/^PRODUCT=".*"$/p'`" ] && META="$DATA"
fi

[ -z "$META" ] && { error "Failed to locate the product's metadata!" ; exit 1 ; }

#-------------------------------------------------------------------------------
# detect the metadata format
_xml_root="`xml_extract.py "$META" './name()'`"
if [ $? -eq 0 ]
then # XML format
    if [ "$_xml_root" == "Dimap_Document" ]
    then
        METADATA_FORMAT="`xml_extract.py "$META" '//METADATA_FORMAT/text()'`"
        DIMAP_VERSION="`xml_extract.py "$META" '//METADATA_FORMAT/@version'`"
        DIMAP_PROFILE="`xml_extract.py "$META" '//METADATA_PROFILE/text()'`"
        info "Metadata format: $METADATA_FORMAT, $DIMAP_VERSION, $DIMAP_PROFILE"
    elif [ "$_xml_root" == '{http://www.opengis.net/eop/2.0}EarthObservation' ]
    then
        METADATA_FORMAT='EOP20'
        info "Metadata format: $METADATA_FORMAT"
    elif [ "$_xml_root" == '{http://www.opengis.net/eop/2.1}EarthObservation' ]
    then
        METADATA_FORMAT='EOP21'
        info "Metadata format: $METADATA_FORMAT"
    else
        error "Unsupported XML metadata format! META=$META XML_ROOT=$_xml_root"
        exit 1
    fi
else # non-XML format
    if [ -n "`head -n 1 "$META" | sed -ne '/^PRODUCT=".*"$/p'`" ]
    then
        METADATA_FORMAT='ENVISAT'
        N1_PRODUCT="`head -n 1 "$META" | sed -ne 's/^PRODUCT="\(.*\)"$/\1/p'`"
        info "Metadata format: $METADATA_FORMAT, $N1_PRODUCT"
    else
        error "Unsupported XML metadata format! META=$META"
    fi
fi

#-------------------------------------------------------------------------------
# product specific metadata handling

if [ "$METADATA_FORMAT" == "DIMAP" ]
then
    info "DIMAP metadata ..."
    if [ "$DIMAP_VERSION" == "1.1" -a "$DIMAP_PROFILE" == "SPOTView" ]
    then #
        # SPOT 2/4/5 ortho imagery
        . "`dirname $0`/products.d/spotview.sh"
    elif [ "$DIMAP_VERSION" == "1.1" -a "$DIMAP_PROFILE" == "SPOTSCENE_1A" ]
    then
        # SPOT 4/5 RAW imagery + Spot4-Take5
        . "`dirname $0`/products.d/spotscene_1a.sh"
    elif [ "$DIMAP_VERSION" == "2.0" -a "$DIMAP_PROFILE" == "S6_ORTHO" ]
    then
        # SPOT 6 ortho imagery
        RANGE="16 2048"
        BANDS="B2 B1 B0 B3"
        . "`dirname $0`/products.d/spot6_ortho.sh"
    elif [ "$DIMAP_VERSION" == "2.0" -a "$DIMAP_PROFILE" == "PHR_ORTHO" ]
    then
        RANGE="8 1024"
        BANDS="B2 B1 B0 B3"
        # Pleiades ortho imagery
        . "`dirname $0`/products.d/spot6_ortho.sh"
    elif [ "$DIMAP_VERSION" == "2.11.0" -a "$DIMAP_PROFILE" == "BEAM-DATAMODEL-V1" ]
    then
        info "BEAM-DATAMODEL-V1 product ..."
        # BEAM-DIMAP data
        error "NOT IMPLEMENTED!" ; exit 1
    else
        error "Unsupported dimap product! VERSION=$DIMAP_VERSION PROFILE=$DIMAP_PROFILE" ; exit 1
    fi
elif [ "$METADATA_FORMAT" == "EOP20" ]
then
    info "EOP-2.0 metadata ..."
    # direct EOP ingestion
    error "NOT IMPLEMENTED!" ; exit 1
elif [ "$METADATA_FORMAT" == "ENVISAT" ]
then
    info "ENVISAT file format ..."
    case ${N1_PRODUCT:0:9} in
        # MERIS L1B
        'MER_RR__1' | 'MER_FR__1' | 'MER_FRS_1' )
            # Envisat MERIS
            . "`dirname $0`/products.d/envisat.sh"
            ;;
        'ASA_IMP_1' | 'ASA_IMM_1' | 'ASA_WSM_1' )
            . "`dirname $0`/products.d/envisat.sh"
            ;;
        'ASA_APP_1' | 'ASA_APM_1' )
            . "`dirname $0`/products.d/envisat.sh"
            ;;
        *) error "Unsupported product type  ${N1_PRODUCT:0:9}!" ; exit 1 ;;
    esac
else
    error "Unsupported metadata format! FORMAT=$METADATA_FORMAT" ; exit 1
fi

