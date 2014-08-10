#!/usr/bin/env python
#------------------------------------------------------------------------------
#
# spot 4/5 raw product ingestion
#
# Project: Image Processing Tools
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2013 EOX IT Services GmbH
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

info "SPOTSCENE_1A product ..."

# extract band information
_nband="`xml_extract.py "$META" '//Raster_Dimensions/NBANDS/text()'`" || exit 1
if [ "$_nband" -gt 1 ]
then
    _red="`xml_extract.py "$META" '//Image_Display/Band_Display_Order/RED_CHANNEL/text()'`" || exit 1
    _green="`xml_extract.py "$META" '//Image_Display/Band_Display_Order/GREEN_CHANNEL/text()'`" || exit 1
    _blue="`xml_extract.py "$META" '//Image_Display/Band_Display_Order/BLUE_CHANNEL/text()'`" || exit 1
fi
_data="`xml_extract.py "$META" '//Data_Access/Data_File/DATA_FILE_PATH/@href'`" || exit 1
_bits="`xml_extract.py "$META" '//Raster_Encoding/NBITS/text()'`" || exit 1
if [ "$_nband" -eq 1 ]
then
    _type="MINISBLACK"
else
    _type="RGB"
fi

# prepare the filenames
IMG_DIR="`dirname "$META"`"
IMG_DIR="`_expand "$IMG_DIR"`"
IMG_DATA="$IMG_DIR/$_data"
IMG_VIEW="${IMG_DATA%.*}_RGB_WGS84.tif"
IMG_VIEW_OVR="${IMG_VIEW}.ovr"
IMG_META="${IMG_DATA%.*}.xml"
IMG_RTYPE="${IMG_DATA%.*}_range_type.json"

[ -f "$IMG_DATA" ] || { error "Cannot find the data-image! FILE=$IMG_DATA" ; exit 1 ; }

# extract metadata
dimap2rangetype.py "$META" SLOPPY >"$IMG_RTYPE"
dimap2eop.py "$META" >"$IMG_META"

[ "$_nband" -eq 1 ] && IMG_VIEW_RTYPE="GrayAlpha"
[ "$_nband" -gt 1 ] && IMG_VIEW_RTYPE="RGBA"

# generate image preview
if [ ! -f "$IMG_VIEW" ]
then
    _tmp0="`mktemp`.tif"
    trap "_remove '$_tmp0'" EXIT
    info "Generating preview ..."
    _wopt="$WOPT -srcnodata 0 -dstnodata 0 -dstalpha"
    if [ "$_nband" -eq 1 ]
    then
        _remove "$_IMG_VIEW"
        time gdalwarp $_wopt "$IMG_DATA" "$IMG_VIEW" $TOPT -co "PHOTOMETRIC=$_type" || exit 1 
    else
        _remove "$_tmp0"
        time gdal_translate -b $_red -b $_green -b $_blue "$IMG_DATA" "$_tmp0" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
        _remove "$IMG_VIEW"
        time gdalwarp $_wopt "$_tmp0" "$IMG_VIEW" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
        _remove "$_tmp0"
    fi
    trap - EXIT
fi

# generate overviews
if [ ! -f "$IMG_VIEW_OVR" ]
then
    _levels="`get_gdaladdo_levels.py "$IMG_VIEW" 32 8`"
    _adoopt="$ADOOPT --config PHOTOMETRIC_OVERVIEW $_type -ro"
    _remove "$IMG_VIEW_OVR"
    [ -n "$_levels" ]&& time "$GDALADDO" $_adoopt "$IMG_VIEW" $_levels
fi
