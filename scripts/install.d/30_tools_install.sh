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
#then
#    error "EOX Tools seem to be already installed."
#    error "EOX Tools' installation is terminated."
#    exit 1
#fi

#======================================================================
# setup automatic cleanup

on_exit()
{
    [ ! -d "$TOOLS_TMPDIR" ] || rm -fR "$TOOLS_TMPDIR"
}

trap on_exit EXIT

#======================================================================
# list release

get_release_url()
{
    URL_BASE="https://github.com"
    PATH="`curl -S "$URL_BASE/DREAM-ODA-OS/tools/releases" | sed -ne 's/.*href="\(.*\.tar\.gz\)" .*/\1/p' | head -n 1`"
    echo -n "$URL_BASE$PATH"
}

get_filename()
{
    echo -n "`curl -sIL "$1" | sed -ne 's/Content-Disposition:.*filename=\(.*gz\).*/\1/p'`"
}

#======================================================================
# trying to locate the download manager tarball in DM directory

TOOLS_TARBALL="`find "$CONTRIB" -name 'tools*' | grep -e '\.tgz$' -e '\.tar\.gz$' | sort -r | head -n 1`"

if [ -z "$TOOLS_TARBALL" ]
then

    # automatic download of the latest release
    #URL="`get_release_url`"

    #fixed version download
    URL="https://github.com/DREAM-ODA-OS/tools/archive/release-0.1.0.tar.gz"

    info "Downloading from: $URL"

    TOOLS_TARBALL="$CONTRIB/`get_filename "$URL"`"

    info "Saving to : $TOOLS_TARBALL"

    curl -L "$URL" -o "$TOOLS_TARBALL"

    [ -f "$TOOLS_TARBALL" ] || error "Failed to download the EOX Tools release!" \
        && info "EOX Tools downloaded."

else # found - using local copy

    info "Using the existing local copy of the EOX Tools."

fi

info "$TOOLS_TARBALL"

#======================================================================
# unpack the download manager

# clean-up the previous installation if needed
[ -d "$TOOLS_HOME" ] && rm -fR "$TOOLS_HOME"
[ -d "$TOOLS_TMPDIR" ] && rm -fR "$TOOLS_TMPDIR"

# init
mkdir -p "$TOOLS_TMPDIR"

# unpack
tar -xzf "$TOOLS_TARBALL" --directory="$TOOLS_TMPDIR"

# move to destination
TOOLS_ROOT="`find "$TOOLS_TMPDIR" -mindepth 1 -maxdepth 1 -name 'tools*' -type d | head -n 1`"
mv -f "$TOOLS_ROOT" "$TOOLS_HOME"

# fix permisions
chown -R "$ODAOSUSER:$ODAOSGROUP" "$TOOLS_HOME"

#======================================================================

info "EOX Tools installed to: $TOOLS_HOME"

