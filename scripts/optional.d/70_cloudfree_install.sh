#!/bin/sh
#
# download and install the the CloudfreeCoverage processing toolset
#
# Copyright (C) 2014 EOX IT Services GmbH
#
# 
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing the CloudfreeCoverage processing toolset ..."

#======================================================================

[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

CFPROC_INSTDIR="$ODAOSROOT/cf_processor"
CFPROC_TMPDIR="/tmp/cfproc"
CFPROC_URL="https://github.com/DREAM-ODA-OS/CloudfreeCoverage/archive/v0.1.0.tar.gz"

# setup automatic cleanup
on_exit()
{
    [ ! -d "$CFPROC_TMPDIR" ] || rm -fR "$CFPROC_TMPDIR"
}
trap on_exit EXIT

#======================================================================
# trying to locate the file archive

CFPROC_FILE="`find "$CONTRIB" -name 'CloudfreeCoverage*.tar.gz' | sort -r | head -n1`"

if [ -z "$CFPROC_FILE" ]; then
    # download the routines from the git repository
    CFPROC_FILE="$CONTRIB/CloudfreeCoverage-`basename "$CFPROC_URL"`"
    info "Downloading from: $CFPROC_URL"
    info "Saving to: $CFPROC_FILE"
    curl -L -s -S  "$CFPROC_URL" -o "$CFPROC_FILE"
    [ -f "$CFPROC_FILE" ] || { error "Failed to download the CloudfreeCoverage processing toolset." ; exit 1 ; }
else
    info "Local CloudfreeCoverage processing toolset found: $CFPROC_FILE"
    info "Using the existing local copy of the CloudfreeCoverage processing toolset."
fi

#======================================================================
# unpack the archive and install the routines

# clean-up the previous installation if needed
[ -d "$CFPROC_INSTDIR" ] && rm -fR "$CFPROC_INSTDIR"
[ -d "$CFPROC_TMPDIR" ] && rm -fR "$CFPROC_TMPDIR"

# unpack
mkdir -p "$CFPROC_TMPDIR"
tar -xzf "$CFPROC_FILE" --directory="$CFPROC_TMPDIR"

# move the unpacked folder to the installation path 
CFPROC_ROOT="`find "$CFPROC_TMPDIR" -mindepth 1 -maxdepth 1 -name 'CloudfreeCoverage*' -type d | head -n 1`"
mv -f "$CFPROC_ROOT" "$CFPROC_INSTDIR"

# fix permisions
chown -R "$ODAOSUSER:$ODAOSGROUP" "$CFPROC_INSTDIR"

info "Installation of CloudfreeCoverage processing toolset finished"
