#!/bin/sh 
#
# install EOX image and metadata processing tools 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing EOX Tools ... "

#======================================================================

[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

TOOLS_TMPDIR='/tmp/tools'
TOOLS_HOME="$ODAOSROOT/tools"

#if [ -d "$TOOLS_HOME" ] 
if /bin/false
then 
    info "EOX Tools seem to be already installed."
    info "EOX Tools' installation is terminated."
    exit 0 
fi 

#======================================================================
# setup automatic cleanup 

on_exit() 
{ 
    [ ! -d "$TOOLS_TMPDIR" ] || rm -fR "$TOOLS_TMPDIR"
} 

trap on_exit EXIT 

#======================================================================
# trying to locate the download manager tarball in DM directory 

TOOLS_TARBALL="`find "$CONTRIB" -name 'eox-tools*' | grep -e '\.tgz$' -e '\.tar\.gz$' | sort -r | head -n 1`" 

if [ -z "$TOOLS_TARBALL" ] 
then 
    
    # TODO: automatic download of the latest release 
    error "Cannot find the EOX Tools package in the contrib. directory!"

else # found - using local copy  

    info "Using the existing local copy of the EOX Tools."

fi 

info "$TOOLS_TARBALL"

#======================================================================
# unpack the download manager 

# clean-up previous mess 
[ -d "$TOOLS_HOME" ] && rm -fR "$TOOLS_HOME"
[ -d "$TOOLS_TMPDIR" ] && rm -fR "$TOOLS_TMPDIR"

# init 
mkdir -p "$TOOLS_TMPDIR"

# unpack 
tar -xzf "$TOOLS_TARBALL" --directory="$TOOLS_TMPDIR"

# move to destination 
TOOLS_ROOT="`find "$TOOLS_TMPDIR" -mindepth 1 -maxdepth 1 -name 'eox-tools*' -type d | head -n 1`"
mv -f "$TOOLS_ROOT" "$TOOLS_HOME"

# fix permisions 
chown -R "$ODAOSUSER:$ODAOSGROUP" "$TOOLS_HOME"

#======================================================================

info "EOX Tools installed."

