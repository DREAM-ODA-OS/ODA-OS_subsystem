#!/usr/bin/env python
#------------------------------------------------------------------------------
#
# spot 6 ortho product ingestion
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

info "$DIMAP_PROFILE product ..."
RANGE="${RANGE:-16 2048}"

_get_band_idx()
{
    IDX=0
    {
        if [ -z "$BANDS" ]
        then
            xml_extract.py "$META" '//Instrument_Calibration/Band_Measurement_List/Band_Spectral_Range/BAND_ID/text()' PRETTY MULTI
        else
            for B in $BANDS
            do
                echo $B
            done
        fi
    } | while read B
    do
        let 'IDX=IDX+1'
        if [ "$B" == "$1" ]
        then
            echo -n "$IDX"
            break
        fi
    done
}

# extract band information
_nband="`xml_extract.py "$META" '//Raster_Dimensions/NBANDS/text()'`" || exit 1
if [ "$_nband" -gt 1 ]
then
    _bandid_red="`xml_extract.py "$META" '//Raster_Display/Band_Display_Order/RED_CHANNEL/text()'`" || exit 1
    _bandid_green="`xml_extract.py "$META" '//Raster_Display/Band_Display_Order/GREEN_CHANNEL/text()'`" || exit 1
    _bandid_blue="`xml_extract.py "$META" '//Raster_Display/Band_Display_Order/BLUE_CHANNEL/text()'`" || exit 1
    _red=`_get_band_idx $_bandid_red`
    _green=`_get_band_idx $_bandid_green`
    _blue=`_get_band_idx $_bandid_blue`
    if [ -z "$_red" -o -z "$_green" -o -z "$_blue" ]
    then
        error "Failed to extract the RGB band indices!"
        exit 1
    fi
fi
if [ "$_nband" -lt 3 ]
then
    _type="MINISBLACK"
else
    _type="RGB"
fi

# check whether the imagery is tiled or not
_tiled="`xml_extract.py "$META" '//Data_Access/DATA_FILE_TILES/text()'`" || exit 1
_tmp="${META/DIM_/IMG_}"
DATA_LIST="${_tmp%.*}_data_list.txt"
VIEW_LIST="${_tmp%.*}_view_data_list.txt"
IMG_DIR="`dirname "$META"`"
IMG_DIR="`_expand "$IMG_DIR"`"
if [ "$_tiled" == 'true' ]
then
    _data_list_dir="`dirname "$DATA_LIST"`"
    IMG_DATA="${_tmp%.*}.vrt"
    xml_extract.py "$META" '//Data_Access/Data_Files/Data_File/DATA_FILE_PATH/@href' MULTI | while read F
    do
        _detach "$IMG_DIR/$F" "$_data_list_dir"
    done > "$DATA_LIST"
    pushd "$_data_list_dir"
    gdalbuildvrt -overwrite -input_file_list "$DATA_LIST" "$IMG_DATA" || exit 1
    popd
else
    IMG_DATA="$IMG_DIR/`xml_extract.py "$META" '//Data_Access/Data_Files/Data_File/DATA_FILE_PATH/@href' `" || exit 1
fi
IMG_VIEW="${IMG_DATA%.*}_RGB_WGS84.vrt"
IMG_VIEW_OVR="${IMG_VIEW}.ovr"
IMG_META="${IMG_DATA%.*}.xml"
IMG_RTYPE="${IMG_DATA%.*}_range_type.json"

[ -f "$IMG_DATA" ] || { error "Cannot find the data-image! FILE=$IMG_DATA" ; exit 1 ; }

# extract metadata
dimap2rangetype.py "$META" SLOPPY >"$IMG_RTYPE"
dimap2eop.py "$META" DEBUG >"$IMG_META"

[ "$_nband" -lt 3 ] && IMG_VIEW_RTYPE="GrayAlpha"
[ "$_nband" -ge 3 ] && IMG_VIEW_RTYPE="RGBA"

# generate image preview
if [ ! -f "$IMG_VIEW" ]
then
    _view_dir="${IMG_DATA%.*}_view"
    _tmp0="`mktemp --suffix=.tif`"
    _tmp1="`mktemp --suffix=.tif`"
    trap "_remove '$_tmp0' '$_tmp1'" EXIT
    info "Generating preview ..."
    _maxpixsize="10000"
    _proj="EPSG:4326"
    _wopt="$WOPT -t_srs $_proj -srcnodata 0 -dstnodata 0"
    _remove "$_tmp0"
    if [ "$_nband" -lt 3 ]
    then
        _info="Grayscale band"
        _bands="-b 1"
    else
        _info="RGB bands"
        _bands="-b $_red -b $_green -b $_blue"
    fi
    info "Extracting the $_info from $IMG_DATA"
    time gdal_translate $_bands "$IMG_DATA" "$_tmp0" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
    ls -lh "$_tmp0"
    gdalinfo "$_tmp0"
    # guessing of the resolution of the warped image
    _resl="`guess_warped_resolution.py "$IMG_DATA" $_proj`"
    info "Resolution of the $_proj warped image: $_resl"
    # splitting the image to sub-images
    [ -f "$_view_dir" -o -d "$_view_dir" ] && rm -fvR "$_view_dir"
    mkdir -p "$_view_dir"
    _view_list_dir="`dirname "$VIEW_LIST"`"
    _detach "$_view_dir" "$_view_list_dir" >> "$VIEW_LIST"
    _cnt=0
    info "Warping the extracted image to $_img"
    geom_raster_extent.py "$IMG_DATA" | geom_segmentize.py - 1e4 | geom_to_wgs84.py - \
    | geom_split.py - "$_maxpixsize" "$_maxpixsize" "$_resl" "$_resl" | while read _te
    do
        let "_cnt+=1"
        _img="$_view_dir/`printf "%4.4d" $_cnt`.tif"
        info "Generating preview tile: $_img"
        echo $_tr $_img
        _remove "$_tmp1"
        time gdalwarp -te $_te -tr $_resl $_resl $_wopt "$_tmp0" "$_tmp1" $TOPT -co "PHOTOMETRIC=$_type" || exit 1
        time range_stretch.py "$_tmp1" "$_img" $RANGE 0 ADDALPHA `echo $TOPT | sed -e 's/-co//g'` "PHOTOMETRIC=$_type" || exit 1
        _detach "$_img" "$_view_list_dir" >> "$VIEW_LIST"
        info "Generating external overviews."
        _levels="`get_gdaladdo_levels.py "$_img" 32 8`"
        _adoopt="$ADOOPT --config PHOTOMETRIC_OVERVIEW $_type -ro"
        _img_ovr="$_img.ovr"
        _remove "$_img_ovr"
        if [ -n "$_levels" ]
        then
            time "$GDALADDO" $_adoopt "$_img" $_levels || exit 1
        fi
        _detach "$_img_ovr" "$_view_list_dir" >> "$VIEW_LIST"
        _remove "$_tmp1"
    done && gdalbuildvrt -overwrite "$IMG_VIEW" "$_view_dir"/*.tif || exit 1
    info "Preview generation is finished."
    trap - EXIT
else
    info "Using existing preview ..."
fi
