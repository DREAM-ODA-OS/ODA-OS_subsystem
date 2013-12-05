#!/bin/sh
#
# install ngEO downaload manager 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing ngEO Download Manager ... "

#======================================================================

DM_TMPDIR='/tmp/ngeo-dm'

[ -z "$ODAOS_DM_HOME" ] && error "Missing the required ODAOS_DM_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

if [ -d "$ODAOS_DM_HOME" ] 
then 
    info "ngEO Download Manager seems to be already installed."
    info "ngEO Download Manager installation is terminated."
    exit 0 
fi 

#======================================================================
# setup automatic cleanup 

REMOVE_NETRC_BACKUP=FALSE
RESTORE_NETRC_BACKUP=FALSE

on_exit() 
{ 
    [ "$REMOVE_NETRC_BACKUP" == TRUE ] && rm -fv "$HOME/.netrc" 
    [ "$RESTORE_NETRC_BACKUP" == TRUE ] && mv -fv "$HOME/.netrc.bak" "$HOME/.netrc" 

    [ -d "$DM_TMPDIR" ] && rm -fR "$DM_TMPDIR"
} 

trap on_exit EXIT 

#======================================================================
# trying to locate the download manager tarball in DM directory 

DM_TARBALL="`find "$CONTRIB" -name 'download-manager*-linux_x64.tar.gz' | sort | tail -n 1`" 

if [ -z "$DM_TARBALL" ] 
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

    # not found - downloading archive from the spacebel ftp server 

    # NOTE: assuming the server supports NLST command and lists directories

    BASEURL="ftp://ftp.spacebel.be/Inbox/ASU/MAGELLIUM/DMTU-Releases"

    # select the latest DM version available 
    info "Listing: $BASEURL/"
    DM_VERSION=`curl -n -l "$BASEURL/" | grep '^[0-9]*\.[0-9]*\.[0-9]*' | sort | tail -n 1`

    [ -z "$DM_VERSION" ] && { echo "ERROR: Failed to locate the DM download directory!" >&2 ; exit 1 ; } 

    # select binary tarball to be used 
    info "Listing: $BASEURL/$DM_VERSION/"
    DM_ARCHIVE=`curl -n -l "$BASEURL/$DM_VERSION/" | grep -m 1 '^download-manager.*-linux_x64\.tar\.gz$'`

    [ -z "$DM_ARCHIVE" ] && { echo "ERROR: Failed to locate the DM package!" >&2 ; exit 1 ; } 

    # download the DM tarball 

    DM_TARBALL="$CONTRIB/$DM_ARCHIVE"

    info "Donwloading the ngEO Download Manager: ... "
    info "$BASEURL/$DM_VERSION/$DM_ARCHIVE -> $DM_TARBALL"
    curl -n -s -S "$BASEURL/$DM_VERSION/$DM_ARCHIVE" -o "$DM_TARBALL"
    info "Download manager downloaded."

else # found - using local copy  

    info "Using the existing local copy of the donwload manager."

fi 

info "$DM_TARBALL"

#======================================================================
# unpack the download manager 

# clean-up previous mess 
[ -d "$ODAOS_DM_HOME" ] && rm -fR "$ODAOS_DM_HOME"
[ -d "$DM_TMPDIR" ] && rm -fR "$DM_TMPDIR"

# init 
mkdir -p "$DM_TMPDIR"

# unpack 
tar -xzf "$DM_TARBALL" --directory="$DM_TMPDIR"

# move to destination 
mv -f "$DM_TMPDIR/ngEO-download-manager" "$ODAOS_DM_HOME"

# fix permisions 
chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_DM_HOME"

# TODO: get rid of the embedded JRE 
