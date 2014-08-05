#!/bin/sh
#
# install NLR eXcat2 CSW catalogue
#
#======================================================================

. `dirname $0`/../lib_logging.sh
. `dirname $0`/../lib_apache.sh

info "Installing eXcat2 ... "

XCAT_TMPDIR="/tmp/excat2"
XCAT_WEBAPPDIR="/usr/share/tomcat/webapps"
XCAT_NAME="excat2"

[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"

service tomcat stop || :

#======================================================================
# setup automatic cleanup

on_exit()
{
    [ ! -d "$XCAT_TMPDIR" ] || rm -fR "$XCAT_TMPDIR"
}

trap on_exit EXIT

#======================================================================
# trying to locate the ingestion package

XCAT_ZIP="`find "$CONTRIB" -name 'excat2-*.zip' | sort -r | head -n 1`"

if [ -z "$XCAT_ZIP" ]
then
    warn "The eXcat installation package was not found in the contrib directory! CONTRIB=$CONTRIB"
    warn "The eXcat is aborted!"
    exit 0
else
    info "The eXcat installation package found in in the contrib directory."
fi

info "$XCAT_ZIP"

#======================================================================
# unpack and deploy the WAR file

# clean-up the old files
[ -d "$XCAT_TMPDIR" ] && rm -fR "$XCAT_TMPDIR"
[ -d "$XCAT_WEBAPPDIR/$XCAT_NAME" ] && rm -fR "$XCAT_WEBAPPDIR/$XCAT_NAME"
[ -f "$XCAT_WEBAPPDIR/$XCAT_NAME.war" ] && rm -fR "$XCAT_WEBAPPDIR/$XCAT_NAME.war"

mkdir -p "$XCAT_TMPDIR"

#unpack the archive
unzip "$XCAT_ZIP" -d "$XCAT_TMPDIR"

if [ -f "$XCAT_TMPDIR/$XCAT_NAME.war" ]
then
    info "Deploying the eXcat WAR file..."
    mv "$XCAT_TMPDIR/$XCAT_NAME.war" "$XCAT_WEBAPPDIR"
else
    error "Failed to locate the eXcat uncomressed WAR file! FILE=$XCAT_TMPDIR/$XCAT_NAME.war"
    exit 1
fi

service tomcat start

#======================================================================
# set the reverse proxy

info "Setting eXcat app behind the Apache reverse proxy ..."

# locate proper configuration file (see also apache configuration)
{
    locate_apache_conf 80
    locate_apache_conf 443
} | while read CONF
do
    # delete any previous configuration and write a new one
    { ex "$CONF" || /bin/true ; } <<END
/XCT00_BEGIN/,/XCT00_END/de
/^[ 	]*<\/VirtualHost>/i
    # XCT00_BEGIN - eXcat - Do not edit or remove this line!

    # reverse proxy to the eXcat CSW catalogue
    ProxyPass        /excat2 ajp://127.0.0.1:8089/excat2
    ProxyPassReverse /excat2 ajp://127.0.0.1:8089/excat2

    # XCT00_END - eXcat - Do not edit or remove this line!
.
wq
END
done

#-------------------------------------------------------------------------------
# restart apache to force the changes to take effect

service httpd restart
