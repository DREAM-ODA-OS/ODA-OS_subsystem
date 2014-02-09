#!/bin/sh
#
# install ODA-OS ingestion engine 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing Ingestion Engine ... "

#======================================================================

IE_TMPDIR='/tmp/ieng'

[ -z "$ODAOS_IE_HOME" ] && error "Missing the required ODAOS_IE_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

if [ -d "$ODAOS_IE_HOME" ] 
then 
    info "Ingestion Engine seems to be already installed."
    info "Ingestion Engine installation is terminated."
    exit 0 
fi 

#======================================================================
# setup automatic cleanup 

on_exit() 
{ 
    [ ! -d "$EI_TMPDIR" ] || rm -fR "$EI_TMPDIR"
} 

trap on_exit EXIT 

#======================================================================
# list release 

get_release_url()
{ 
    URL_BASE="https://github.com"

    PATH="`curl "$URL_BASE/DREAM-ODA-OS/IngestionEngine/releases" | sed -ne 's/.*href="\(.*\.tar\.gz\)" .*/\1/p' | head -n 1`"

    echo -n "$URL_BASE$PATH"
} 

get_filename()
{ 
    echo -n "`curl -sIL "$1" | sed -ne 's/Content-Disposition:.*filename=\(.*gz\).*/\1/p'`"
} 

#======================================================================
# trying to locate the download manager tarball in DM directory 

IE_TARBALL="`find "$CONTRIB" -name 'IngestionEngine*' | grep -e '\.tgz$' -e '\.tar\.gz$' | sort -r | head -n 1`" 

if [ -z "$IE_TARBALL" ] 
then 
    
    # automatic download of the latest release 

    URL="`get_release_url`"

    info "Downaloding latest release from: $URL"

    IE_TARBALL="$CONTRIB/`get_filename "$URL"`"

    info "Saving to : $IE_TARBALL"

    curl -L "$URL" -o "$IE_TARBALL"

    [ -f "$IE_TARBALL" ] || error "Failed to download the Ingestion Engine release!" \
        && info "Ingestion Engine downloaded."

else # found - using local copy  

    info "Using the existing local copy of the Ingestion Engine."

fi 

info "$IE_TARBALL"

#======================================================================
# unpack the download manager 

# clean-up previous mess 
[ -d "$ODAOS_IE_HOME" ] && rm -fR "$ODAOS_IE_HOME"
[ -d "$IE_TMPDIR" ] && rm -fR "$IE_TMPDIR"

# init 
mkdir -p "$IE_TMPDIR"

# unpack 
tar -xzf "$IE_TARBALL" --directory="$IE_TMPDIR"

# move to destination 
IE_ROOT="`find "$IE_TMPDIR" -name 'IngestionEngine*' -mindepth 1 -maxdepth 1 -type d | head -n 1`"
mv -f "$IE_ROOT" "$ODAOS_IE_HOME"

# fix permisions 
chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_IE_HOME"

info "Ingestion Engine installed."
