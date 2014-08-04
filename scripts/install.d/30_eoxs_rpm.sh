#!/bin/sh
#
# install EOxServer RPM 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing EOxServer ... "

#======================================================================

[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"

get_release_url()
{ 
    URL_BASE="https://github.com"
    PATH="`curl -s "$URL_BASE/DREAM-ODA-OS/eoxserver/releases" | sed -ne 's/.*href="\(.*\.x86_64\.rpm\)" .*/\1/p' | head -n 1`"
    echo -n "$URL_BASE$PATH"
} 

download()
{ 
    _URL=$1
    _DIR=$2
    _BN="_EOxServer"

    # NOTE: The curl on CentOS 6 does not support content-disposition
    #       and the remote ec-s3 storage HTTP server does not support 
    #       HTTP/HEAD requests. 
    { 
        curl -L -D "$_DIR/$_BN.header" "$_URL" -o "$_DIR/$_BN.rpm" && \
        { 
            _FN="`cat "$_DIR/$_BN.header" | sed -ne 's/Content-Disposition:.*filename=\(.*[a-zA-Z]\).*/\1/p'`" 
            ls -l "$_DIR" &&
            mv "$_DIR/$_BN.rpm" "$_DIR/$_FN"
        } && rm "$_DIR/$_BN.header" 
    } >&2 && echo -n "$_DIR/$_FN"
} 

#======================================================================
# trying to locate the EOxServer RPM package 

EOXS_RPM="`find "$CONTRIB" -name 'EOxServer*.rpm' | sort -r | head -n 1`" 

if [ -z "$EOXS_RPM" ] 
then 
    
    # automatic download of the latest release 
    #URL="`get_release_url`"

    #fixed version download
    URL="https://github.com/DREAM-ODA-OS/eoxserver/releases/download/release-0.4-dream-0.3.1/EOxServer_dream-0.4dev4-1.x86_64.rpm"

    info "Downloading from: $URL"

    EOXS_RPM="`download "$URL" "$CONTRIB"`"

    info "Saving to : $EOXS_RPM"

else # found - using local copy  

    info "Using the existing local copy of the Ingestion Engine."

fi 

info "$EOXS_RPM"

#======================================================================
#    yum --assumeyes install proj-epsg fcgi gd libXpm libxml2-python mapserver mapserver-python python-ipaddr python-lxml
if [ -z "`rpm -qa | grep EOxServer`" ] 
then 
    yum --assumeyes install "$EOXS_RPM"
else 
    yum --assumeyes update "$EOXS_RPM"
fi

