#!/bin/sh
#
# download and install FW tools
#
# Copyright (C) 2014 EOX IT Services GmbH
#
#======================================================================


. `dirname $0`/../lib_logging.sh

info "Installing the FWTools ..."

#======================================================================

[ -z "$ODAOS_FWTOOLS_HOME" ] && error "Missing the required ODAOS_FWTOOLS_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

FWT_TMPDIR='/tmp/fwtools'
FWT_URL='http://home.gdal.org/fwtools/FWTools-linux-x86_64-3.0.6.tar.gz'

# setup automatic cleanup
on_exit()
{
    [ ! -d "$FWT_TMPDIR" ] || rm -fR "$FWT_TMPDIR"
}
trap on_exit EXIT

#======================================================================
# trying to locate the file archive

FWT_FILE="`find "$CONTRIB" -name 'FWTools-linux-x86_64-*.tar.gz' | sort -r | head -n 1`"

if [ -z "$FWT_FILE" ]
then

    # download the archive
    FWT_FILE="$CONTRIB/`basename "$FWT_URL"`"
    info "Downloading from: $FWT_URL"
    info "Saving to: $FWT_FILE"
    curl -L -s -S "$FWT_URL" -o "$FWT_FILE"

    [ -f "$FWT_FILE" ] || { error "Failed to download the FWTools." ; exit 1 ; }

else
    info "Installer found: $FWT_FILE"
    info "Using the existing local copy of the FWTools."
fi

#======================================================================
# installation
# cleanup old stuff

[ ! -d "$FWT_TMPDIR" -a ! -f "$FWT_TMPDIR" ] || rm -fR "$FWT_TMPDIR"
mkdir -p "$FWT_TMPDIR"

# unpack the archive
tar -xzf "$FWT_FILE" -C "$FWT_TMPDIR" || echo FAILED

# move to destination
FWT_ROOT="`find "$FWT_TMPDIR" -mindepth 1 -maxdepth 1 -name 'FWTools-linux*' -type d | head -n 1`"
[ ! -d "$ODAOS_FWTOOLS_HOME" -a ! -f "$ODAOS_FWTOOLS_HOME" ] || rm -fR "$ODAOS_FWTOOLS_HOME"
mv -f "$FWT_ROOT" "$ODAOS_FWTOOLS_HOME"

# fix permisions
chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_FWTOOLS_HOME"

pushd "$ODAOS_FWTOOLS_HOME"
sudo -u "$ODAOSUSER" sh -x "./install.sh"
popd

info "FWTools installed to: $ODAOS_FWTOOLS_HOME"
