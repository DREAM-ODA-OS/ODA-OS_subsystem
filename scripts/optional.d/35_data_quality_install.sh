#!/bin/sh
#
# install Data Quality subsystem
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing Data Quality subsytem ... "

#======================================================================

DQ_TMPDIR='/tmp/data-quality'

[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
[ -z "$ODAOSDATADIR" ] && error "Missing the required ODAOSDATADIR variable!"
[ -z "$ODAOS_DQ_HOME" ] && error "Missing the required ODAOS_DQ_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"
[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"

#if [ -d "$ODAOS_DQ_HOME" ]
#then
#    error "Data Quality subsytem seems to be already installed in: $ODAOS_DQ_HOME"
#    error "Data Quality subsytem installation is terminated."
#    exit 0
#fi

# try to stop the service if it is running
DQ_SERVICE="tomcat-dq"
[ ! -f "/etc/init.d/$DQ_SERVICE" ] || service "$DQ_SERVICE" stop

#======================================================================
# setup automatic cleanup

REMOVE_NETRC_BACKUP=FALSE
RESTORE_NETRC_BACKUP=FALSE

on_exit()
{
    [ "$REMOVE_NETRC_BACKUP" != TRUE ] || rm -fv "$HOME/.netrc"
    [ "$RESTORE_NETRC_BACKUP" != TRUE ] || mv -fv "$HOME/.netrc.bak" "$HOME/.netrc"

    [ ! -d "$DQ_TMPDIR" ] || rm -fR "$DQ_TMPDIR"
}

trap on_exit EXIT

#======================================================================
# locate a download manager tarball in the DM directory

# fixed source URL
DQ_URL='ftp://dream-reader@ftp.spacebel.be/Inbox/ASV%20GEO/QSS/0.8/qss-0.8.tgz'
DQ_TARBALL="$CONTRIB/`basename "$DQ_URL"`"

if [ -f "$DQ_TARBALL" ]
then
    # found - using local copy
    info "Using the existing local copy of the Data Quality installation package."

else
    # not found - download the package

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

    info "Donwloading the Data Quality installation package ... "
    info "$DQ_URL -> $DQ_TARBALL"
    curl -n -s -S "$DQ_URL" -o "$DQ_TARBALL"
    info "Download completed."

fi

info "$DQ_TARBALL"

#======================================================================
# unpack the download manager

# clean-up any existing stuff
{
    echo "$ODAOS_DQ_HOME"
    echo "$ODAOSROOT/.constellation"
    echo "$ODAOSROOT/.constellation-data"
    echo "$ODAOSROOT/.geotoolkit.org"
    echo "$ODAOSROOT/.dream"
    echo "$ODAOSROOT/derby.log"
    echo "$ODAOSLOGDIR/data-quality"
    echo "$ODAOSDATADIR/data-quality"
    echo "$DQ_TMPDIR"
} | while read ITEM
do
    [ -d "$ITEM" -o -f "$ITEM" -o -h "$ITEM" ] && rm -fR "$ITEM" || :
done

mkdir -p "$DQ_TMPDIR"
tar -xzf "$DQ_TARBALL" --directory="$DQ_TMPDIR"

[ 1 -eq `find "$DQ_TMPDIR" -mindepth 1 -maxdepth 1 -type d | wc -l` ] || {
    ls -la "$DQ_TMPDIR"
    error "Cannot locate a suitable installation directory!"
}

DQ_TMP_SRC="`find "$DQ_TMPDIR" -mindepth 1 -maxdepth 1 -type d`"

[ -d "$DQ_TMP_SRC" ] || error "Cannot find the '$DQ_TMP_SRC' directory!"

# move to the destination
mv -f "$DQ_TMP_SRC" "$ODAOS_DQ_HOME"

# fix permisions
chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_DQ_HOME"

info "Data Quality subsytem installed to: $ODAOS_DQ_HOME"
