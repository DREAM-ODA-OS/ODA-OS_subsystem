#!/bin/sh
#
# install EOxServer RPM
#
#======================================================================

. `dirname $0`/../lib_logging.sh
. `dirname $0`/../lib_apache.sh

info "Installing EOxServer ... "

# number of EOxServer deamon processess
EOXSNPROC=${EOXSNPROC:-4}

[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

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
    URL="https://github.com/DREAM-ODA-OS/eoxserver/releases/download/release-0.4-dream-0.4.1/EOxServer_dream-0.4dev8-1.x86_64.rpm"

    info "Downloading from: $URL"

    EOXS_RPM="`download "$URL" "$CONTRIB"`"

    info "Saving to : $EOXS_RPM"

else # found - using local copy

    info "Using the existing local copy of the Ingestion Engine."

fi

info "$EOXS_RPM"

#======================================================================
# install the RPMs

#    yum --assumeyes install proj-epsg fcgi gd libXpm libxml2-python mapserver mapserver-python python-ipaddr python-lxml
if [ -z "`rpm -qa | grep EOxServer`" ]
then
    yum --assumeyes install "$EOXS_RPM"
else
    yum --assumeyes update "$EOXS_RPM"
fi

#======================================================================
# setup the common WSGI daemon

WSGI_DAEMON="WSGIDaemonProcess eoxs_ows processes=$EOXSNPROC threads=1 user=$ODAOSUSER group=$ODAOSGROUP"
CONF="`locate_wsgi_daemon eoxs_ows`"
if [ -z "$CONF" ]
then
    cat >> /etc/httpd/conf.d/wsgi.conf <<END

# WSGI process daemon used by the EOxServer
$WSGI_DAEMON
END
else
    ex "$CONF" <<END
g/^[ 	]*WSGIDaemonProcess[ 	]*eoxs_ows/d
a
$WSGI_DAEMON
.
wq
END
fi

service httpd restart
