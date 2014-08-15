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

beam_meris_l1_tristim_graph() 
{ 
cat <<END
<graph id="meris_1b_RGB_tristimulus">
    <version>1.0</version> 
    <node id="band_composer">
        <operator>BandMaths</operator>
        <sources>
            <sourceProducts>\${INPUT}</sourceProducts>
        </sources>
        <parameters>
            <targetBands>
                <targetBand>
                    <name>valid</name>
                    <expression> ((radiance_1>0)&amp;&amp;(radiance_2>0)&amp;&amp;(radiance_3>0)&amp;&amp;(radiance_4>0)&amp;&amp;(radiance_5>0)&amp;&amp;(radiance_6>0)&amp;&amp;(radiance_7>0)) ? 1.0 : 0.0 </expression>
                    <description>valid pixel flag</description>
                    <type>float32</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
                <targetBand>
                    <name>red0</name>
                    <expression>(1.0+max(0,254*scale*(log(1.0 + 0.35 * radiance_2 + 0.60 * radiance_5 + radiance_6 + 0.13 * radiance_7)+r_off)/r_scl))</expression>
                    <description>pseudo-red-tmp</description>
                    <type>float32</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
                <targetBand>
                    <name>green0</name>
                    <expression>1.0+max(0,254*scale*(log(1.0 + 0.21 * radiance_3 + 0.50 * radiance_4 + radiance_5 + 0.38 * radiance_6)+g_off)/g_scl)</expression>
                    <description>pseudo-green-tmp</description>
                    <type>float32</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
                <targetBand>
                    <name>blue0</name>
                    <expression>1.0+max(0,254*scale*(log(1.0 + 0.21 * radiance_1 + 1.75 * radiance_2 + 0.47 * radiance_3 + 0.16 * radiance_4)+b_off)/b_scl)</expression>
                    <description>pseudo-blue-tmp</description>
                    <type>float32</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
            </targetBands>
            <variables>
                <variable>
                    <name>scale</name>
                    <type>float32</type>
                    <value>1.37</value>
                </variable>
                <variable>
                    <name>r_off</name>
                    <type>float32</type>
                    <value>-3.87</value>
                </variable>
                <variable>
                    <name>g_off</name>
                    <type>float32</type>
                    <value>-3.955</value>
                </variable>
                <variable>
                    <name>b_off</name>
                    <type>float32</type>
                    <value>-4.705</value>
                </variable>
                <variable>
                    <name>r_scl</name>
                    <type>float32</type>
                    <value>3.09</value>
                </variable>
                <variable>
                    <name>g_scl</name>
                    <type>float32</type>
                    <value>3.07</value>
                </variable>
                <variable>
                    <name>b_scl</name>
                    <type>float32</type>
                    <value>2.59</value>
                </variable>
            </variables>
        </parameters>
    </node>
    <node id="band_composer2">
        <operator>BandMaths</operator>
        <sources>
            <source>band_composer</source>
        </sources>
        <parameters>
            <targetBands>
                <targetBand>
                    <name>red</name>
                    <expression>red0*valid</expression>
                    <description>pseudo-red</description>
                    <type>uint16</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
                <targetBand>
                    <name>green</name>
                    <expression>green0*valid</expression>
                    <description>pseudo-green</description>
                    <type>uint16</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
                <targetBand>
                    <name>blue</name>
                    <expression>blue0*valid</expression>
                    <description>pseudo-blue</description>
                    <type>uint16</type>
                    <noDataValue>0</noDataValue>                  
                </targetBand>              
            </targetBands>
        </parameters>
    </node>
    <node id="projector">
        <operator>Reproject</operator>
        <sources>
            <source>band_composer2</source>
        </sources>
        <parameters>
            <crs>EPSG:4326</crs>
            <resampling>Nearest</resampling>
            <noDataValue>0</noDataValue>
            <includeTiePointGrids>false</includeTiePointGrids>
            <addDeltaBands>false</addDeltaBands>
        </parameters>
    </node>
    <node id="writer">
        <operator>Write</operator>
        <sources>
            <source>projector</source>
        </sources>
        <parameters>
            <file>\${OUTPUT}</file>
            <formatName>GeoTIFF</formatName>
            <deleteOutputOnFailure>true</deleteOutputOnFailure>
            <writeEntireTileRows>false</writeEntireTileRows>
            <clearCacheAfterRowWrite>true</clearCacheAfterRowWrite>
        </parameters>
    </node>
</graph>
END
} 

IMG_DATA="${DATA}"
IMG_META="${IMG_DATA%.*}.xml"
IMG_RTYPE="${IMG_DATA%.*}_range_type.json"
IMG_VIEW="${IMG_DATA%.*}_RGB_WGS84.tif"
IMG_VIEW_OVR="${IMG_VIEW}.ovr"

_tmp_eop_xml="${IMG_META}_eop.xml"
_tmp_ftp_wkb="${IMG_META}_ftp.wkb"
_tmp_cnt_wkb="${IMG_META}_wkb.wkb"

# extract EO-metadata
envisat2rangetype.py "$IMG_DATA" > "$IMG_RTYPE"
envisat2eop.py "$IMG_DATA" > "$_tmp_eop_xml"
geom_envistat_footprint.py "$IMG_DATA" > "$_tmp_ftp_wkb"
geom_envistat_center.py "$IMG_DATA" > "$_tmp_cnt_wkb"
geom_to_wgs84.py "$_tmp_ftp_wkb" | geom_loop_orientation_force.py - CCW WKT | eop_add_footprint.py "$_tmp_eop_xml" '-' "$_tmp_cnt_wkb" > "$IMG_META"
IMG_REG_OPT="--extent=`geom_extent_print.py "$_tmp_ftp_wkb" | cut -f 2 -d ';'`"
rm -fv "$_tmp_eop_xml" "$_tmp_ftp_wkb" "$_tmp_cnt_wkb"

# extract previews 

if [ ${N1_PRODUCT:0:3} == "ASA" ] 
then
    # ASAR dB scale view 
    IMG_VIEW_RTYPE="GrayAlpha"
    _type="MINISBLACK"
    if [ ! -f "$IMG_VIEW" ]
    then
        _tmp0="`mktemp`.tif"
        _tmp1="`mktemp`.tif"
        trap "_remove '$_tmp0' '$_tmp1'" EXIT
        _remove "$_tmp0"
        # reproject the image 
        if [ "`gdalinfo "$IMG_DATA" | grep GCP\\\[ | wc -l`" -le 55 ]
        then
            gdalwarp -t_srs EPSG:4326 -tps2 "$IMG_DATA" "$_tmp0" $TOPT || exit 1
        else
            gdalwarp -t_srs EPSG:4326 -tps2_grid 0 0 "$IMG_DATA" "$_tmp0" $TOPT || exit 1
        fi

        # create range stretched dB view 
        if [ ${N1_PRODUCT:4:2} == "AP" ]
        then
            _remove "$_tmp1"
            gdal_translate -b 1 "$_tmp0" "$_tmp1" $TOPT || exit 1
            range_stretch.py "$_tmp1" "$IMG_VIEW" 23 41 0 dB `echo $TOPT | sed -e 's/-co//g'` || exit 1
        else 
            range_stretch.py "$_tmp0" "$IMG_VIEW" 23 41 0 dB `echo $TOPT | sed -e 's/-co//g'` || exit 1
        fi 
        _remove "$_tmp0" "$_tmp1"
        trap - EXIT
    fi

elif [ ${N1_PRODUCT:0:3} == "MER" ] 
then
    # MERIS fake tri-stimulus 
    IMG_VIEW_RTYPE="RGBA"
    _type="RGB"
    if [ ! -f "$IMG_VIEW" ]
    then
        _tmpG="`mktemp`.gpt"
        _tmp0="`mktemp`.tif"
        trap "_remove '$_tmpG' '$_tmp0'" EXIT
        beam_meris_l1_tristim_graph > "$_tmpG"
        gpt.sh "$_tmpG" -c 256M -e -SINPUT="$IMG_DATA" -POUTPUT="$_tmp0" || exit 1
        range_stretch.py "$_tmp0" "$IMG_VIEW" 2 255 0 ADDALPHA `echo $TOPT | sed -e 's/-co//g'` "PHOTOMETRIC=RGB" || exit 1
        _remove "$_tmpG" "$_tmp0"
        trap - EXIT
    fi
fi

# generate overviews
if [ ! -f "$IMG_VIEW_OVR" ]
then
    _levels="`get_gdaladdo_levels.py "$IMG_VIEW" 32 8`"
    _adoopt="$ADOOPT --config PHOTOMETRIC_OVERVIEW $_type -ro"
    _remove "$IMG_VIEW_OVR"
    [ -n "$_levels" ]&& time "$GDALADDO" $_adoopt "$IMG_VIEW" $_levels
fi
