#!/usr/bin/env python
#------------------------------------------------------------------------------
#
# spot 2/4/5 view product ingestion
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

info "Updating: $IDENTIFIER ..."

_proj2srs()
{
    python -c '
DICT = {
    "CRS:84": "EPSG:4326",
}
from sys import stdin, stdout;
from osgeo import osr
with file(next(stdin).strip()) as fid:
    esri_proj = fid.read()
sr = osr.SpatialReference()
sr.ImportFromESRI(esri_proj.split())
sr.AutoIdentifyEPSG()
if sr.GetAuthorityName(None):
    srs = "%s:%s"%(sr.GetAuthorityName(None), sr.GetAuthorityCode(None))
    srs = DICT.get(srs, srs)
    stdout.write(srs)
'
}

# locate all expected files
_dq_prj="`find "$DATA" -name \*.prj | _one_line_only "$_msg"`"
_dq_tfw="`find "$DATA" -name \*.tfw | _one_line_only "$_msg"`"
_dq_tif="`find "$DATA" -name \*.tif | _one_line_only "$_msg"`"
_dq_xml="`find "$DATA" -name \*.xml | _one_line_only "$_msg"`"
#_dq_iso="${_dq_dat=%.*}.iso19115.xml"

[ -n "$_dq_prj" ] || { error "Filed to locate the ESRI projection file!" ; exit 1 ; }
[ -n "$_dq_tfw" ] || { error "Filed to locate the ESRI world file!" ; exit 1 ; }
[ -n "$_dq_tif" ] || { error "Filed to locate the TIFF image!" ; exit 1 ; }
[ -n "$_dq_xml" ] || { error "Filed to locate the XML metadata!" ; exit 1 ; }

# fix the geotiff
_tmp0="`mktemp --suffix=.tif`"
trap "_remove '$_tmp0'" EXIT
info "Fixing the GeoTIFF geocoding ..."
$GDAL_TRANSLATE -a_srs "`echo "$_dq_prj" | _proj2srs`" "$_dq_tif" "$_tmp0" && mv "$_tmp0" "$_dq_tif"
trap - EXIT

# get the metadta of the source coverage
info "Copying the EOP metadata ..."
$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER"
_src_dat="`$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER" | grep '^[^;]*;data' | cut -f 1 -d ';'`"
_src_eop="`$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER" | grep '^[^;]*;metadata;EOP2.0' | cut -f 1 -d ';'`"
_dq_eop="${_dq_tif%.*}_eop20.xml"
[ -f "$_src_eop" ] || { error "Failed to locate the source EOP metadata!" ; exit 1 ; }
cp -v "$_src_eop" "$_dq_eop"

info "Copying the range-type ..."
_src_rtype="`$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER" | grep '^[^;]*;file;range-type' | cut -f 1 -d ';'`"
_dq_rtype="${_dq_tif%.*}_range_type.json"
[ -f "$_src_rtype" ] || { error "Failed to locate the source range-type!" ; exit 1 ; }
cp -v "$_src_rtype" "$_dq_rtype"

_nband="`jq '.bands | length' "$_dq_rtype"`"

# prepare the filenames
IMG_DIR="$DATA"
IMG_DATA="$_dq_tif"
IMG_VIEW="${IMG_DATA%.*}_view.tif"
IMG_VIEW_OVR="${IMG_VIEW}.ovr"
IMG_META="$_dq_eop"
IMG_RTYPE="$_src_rtype"

if [ "$_nband" -lt 3 ]
then
    _type="MINISBLACK"
    IMG_VIEW_RTYPE="GrayAlpha"
else
    _type="RGB"
    IMG_VIEW_RTYPE="RGBA"
fi

# generate image preview
if [ ! -f "$IMG_VIEW" ]
then
    _tmp0="`mktemp --suffix=.tif`"
    trap "_remove '$_tmp0'" EXIT
    info "Generating preview ..."
    _wopt="$WOPT -t_srs EPSG:4326 -srcnodata 0 -dstnodata 0 -dstalpha"
    if [ "$_nband" -eq 1 ]
    then
        _remove "$_IMG_VIEW"
        time $GDALWARP $_wopt "$IMG_DATA" "$IMG_VIEW" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
    else
        _remove "$_tmp0"
        time $GDAL_TRANSLATE -b 1 -b 2 -b 3 "$IMG_DATA" "$_tmp0" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
        _remove "$IMG_VIEW"
        time $GDALWARP $_wopt "$_tmp0" "$IMG_VIEW" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
        _remove "$_tmp0"
    fi
    trap - EXIT
else
    info "Using existing preview ..."
fi

#TODO: footprint extraction

# generate overviews
if [ ! -f "$IMG_VIEW_OVR" ]
then
    _levels="`get_gdaladdo_levels.py "$IMG_VIEW" 32 8`"
    _adoopt="$ADOOPT --config PHOTOMETRIC_OVERVIEW $_type -ro"
    _remove "$IMG_VIEW_OVR"
    [ -n "$_levels" ]&& time "$GDALADDO" $_adoopt "$IMG_VIEW" $_levels
fi

# clean the old records
#$EOXS_MNG eoxs_i2p_list -f -i "$IDENTIFIER" | grep -v directory | $EOXS_MNG eoxs_i2p_delete
