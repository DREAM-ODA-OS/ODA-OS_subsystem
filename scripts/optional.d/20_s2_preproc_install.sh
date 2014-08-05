#!/bin/sh
#
# download and install the GISAT's S2-preprocessor
#
# Copyright (C) 2014 EOX IT Services GmbH
#
# NOTE: requires BEAM Toolbox to be installed
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing the S2-preprocessor (BEAM Toolbox plugins) ..."

#======================================================================

[ -z "$ODAOS_BEAM_HOME" ] && error "Missing the required ODAOS_BEAM_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

S2PP_TMPDIR='/tmp/s2pp'
S2PP_URL="ftp://ftp.spacebel.be/Inbox/EOX/software/gisat/20140618_gisat_s2-preprocessors.tgz"

# setup automatic cleanup
on_exit()
{
    [ "$REMOVE_NETRC_BACKUP" != TRUE ] || rm -fv "$HOME/.netrc"
    [ "$RESTORE_NETRC_BACKUP" != TRUE ] || mv -fv "$HOME/.netrc.bak" "$HOME/.netrc"
    [ ! -d "$S2PP_TMPDIR" ] || rm -fR "$S2PP_TMPDIR"
}
trap on_exit EXIT

#======================================================================
# trying to locate the file archive

S2PP_FILE="`find "$CONTRIB" -name '*_gisat_s2-preprocessors.tgz' | sort -r | head -n 1`"

if [ -z "$S2PP_FILE" ]
then

    # try to use temporarily .netrc in contrib directory
    if [ -f "$CONTRIB/.netrc" ]
    then
        # backup existing .netrc file
        if [ -f "$HOME/.netrc" ]
        then
            mv -fv "$HOME/.netrc" "$HOME/.netrc.bak"
            RESTORE_NETRC_BACKUP=TRUE
        fi
        cp "$CONTRIB/.netrc" "$HOME/.netrc"
        chmod 0600 "$HOME/.netrc"
        REMOVE_NETRC_BACKUP=TRUE
    fi

    # download the archive
    S2PP_FILE="$CONTRIB/`basename "$S2PP_URL"`"
    info "Downloading from: $S2PP_URL"
    info "Saving to: $S2PP_FILE"
    curl -n -s -S "$S2PP_URL" -o "$S2PP_FILE"

    [ -f "$S2PP_FILE" ] || { error "Failed to download the S2 preprocessor." ; exit 1 ; }

else
    info "Installer found: $S2PP_FILE"
    info "Using the existing local copy of the S2 preprocessor."
fi

#======================================================================
# unpack the archive and deploy the modules

BEAM_PLUGIN_DIR="$ODAOS_BEAM_HOME/modules"

# cleanup old stuff
rm -fv "$BEAM_PLUGIN_DIR/beam-s2sim"*.jar || :
[ ! -d "$S2PP_TMPDIR" -a ! -f "$S2PP_TMPDIR" ] || rm -fR "$S2PP_TMPDIR"
mkdir -p "$S2PP_TMPDIR"

# unpack the archive
tar -xvzf "$S2PP_FILE" -C "$S2PP_TMPDIR" || echo FAILED

# install the plugins
for JAR in "$S2PP_TMPDIR/"*.jar
do
    sudo -u "$ODAOSUSER" cp -fv "$JAR" "$BEAM_PLUGIN_DIR"
    sudo -u "$ODAOSUSER" chmod +x "$BEAM_PLUGIN_DIR/`basename "$JAR"`"
done
