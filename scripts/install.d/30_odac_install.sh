#!/bin/sh
#
# install EOxServer RPM 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing ODA-Client ... "

#======================================================================

ODAC_TMPDIR='/tmp/ieng'

[ -z "$ODAOS_ODAC_HOME" ] && error "Missing the required ODAOS_ODAC_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

#if [ -d "$ODAOS_ODAC_HOME" ] 
#then 
#    error "ODA Client seems to be already installed."
#    error "ODA Client installation is terminated."
#    exit 1 
#fi 

#======================================================================
# setup automatic cleanup 

on_exit() 
{ 
    [ ! -d "$ODAC_TMPDIR" ] || rm -fR "$ODAC_TMPDIR"
} 

trap on_exit EXIT 


#======================================================================

[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"

get_release_url()
{ 
    URL_BASE="https://github.com"
    PATH="`curl -s "$URL_BASE/DREAM-ODA-OS/ODAClient/releases" | sed -ne 's/.*href="\(.*\.tgz\)" .*/\1/p' | head -n 1`"
    echo -n "$URL_BASE$PATH"
} 

download()
{ 
    _URL=$1
    _DIR=$2
    _BN="_ODAClient"

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

ODAC_TARBALL="`find "$CONTRIB" -name 'ODAClient*.tgz' | sort -r | head -n 1`" 

if [ -z "$ODAC_TARBALL" ] 
then 
    
    # automatic download of the latest release 
    #URL="`get_release_url`"

    #fixed version download
    URL="https://github.com/DREAM-ODA-OS/ODAClient/releases/download/0.4.4/ODAClient-0.4.4.tgz"

    info "Downloading from: $URL"

    ODAC_TARBALL="`download "$URL" "$CONTRIB"`"

    info "Saving to : $ODAC_TARBALL"

else # found - using local copy  

    info "Using the existing local copy of the ODA Client."

fi 

info "$ODAC_TARBALL"

#======================================================================
# installing the ODA-Client 

# clean-up the previous installation if needed 
[ -d "$ODAOS_ODAC_HOME" ] && rm -fR "$ODAOS_ODAC_HOME"
[ -d "$ODAC_TMPDIR" ] && rm -fR "$ODAC_TMPDIR"

# init 
mkdir -p "$ODAC_TMPDIR"

# unpack 
tar -xzf "$ODAC_TARBALL" --directory="$ODAC_TMPDIR"

# move to destination 
ODAC_ROOT="`find "$ODAC_TMPDIR" -mindepth 1 -maxdepth 1 -name 'ODAClient*' -type d | head -n 1`"
mv -f "$ODAC_ROOT" "$ODAOS_ODAC_HOME"

# fix permisions 
chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_ODAC_HOME"

info "ODA Client installed to: $ODAOS_ODAC_HOME"
