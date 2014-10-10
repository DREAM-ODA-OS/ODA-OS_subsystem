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
XCAT_URL_PATH="/excat2"
WMS_URL="http://${HOSTNAME}/eoxs/ows"

[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"

service tomcat stop || :

#======================================================================
# setup automatic cleanup

on_exit()
{
    #[ ! -d "$XCAT_TMPDIR" ] || rm -fR "$XCAT_TMPDIR"
    echo EXIT
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

#======================================================================
# configuration
# fixing the content of the WAR package before deployment

pushd "$XCAT_TMPDIR"
_WAR="$XCAT_TMPDIR/$XCAT_NAME.war"
_DIR="$_WAR.d"
mkdir -p "$_DIR"
unzip "$_WAR" -d "$_DIR"
cd "$_DIR"

# fix the capabilities.xml
info "Fixing WEB-INF/xml/capabilities.xml ..."
{ ex "WEB-INF/xml/capabilities.xml" || /bin/true ; } <<END
g/\s\+<ows:Get/s#xlink:href="https\=://\([^/]*\)\(/\=.*\)"#xlink:href="http://$HOSTNAME:80$XCAT_URL_PATH/csw?"#
g/\s\+<ows:Post/s#xlink:href="https\=://\([^/]*\)\(/\=.*\)"#xlink:href="http://$HOSTNAME:80$XCAT_URL_PATH/csw?"#
wq
END

# fix the allow.xml
info "Fixing WEB-INF/conf/allow.xml ..."
cat >"WEB-INF/conf/allow.xml" <<END
<?xml version="1.0" encoding="ISO-8859-1"?>
<authorization>
  <harvest>
   <allow host="::1" />
   <allow host="127.0.0.1" />
  </harvest>
  <transaction>
     <allow host="::1" />
     <allow host="127.0.0.1" />
  </transaction>
</authorization>
END

# set the csw-hosts.xml
info "Fixing WEB-INF/conf/csw-hosts.xml ..."
cat >"WEB-INF/conf/csw-hosts.xml" <<END
<?xml version="1.0" encoding="ISO-8859-1"?>
<!--
Configuration file for local and remote CSW hosts;
Purpose of this list of hosts is twofold:
1: defines csw hosts showed in cswclient.
2: defines csw hosts wich will be harvested and how.

        element host can have the following attributes:
	id = some unigue identifier for the host (mandatory)

	optional:
	harvest = "yes|no" (default=no => don't harvest this host)
	method = "post|get" (default=post => http request method)
	maxrecords = negative|positive number (negative means all records will be harvested)
	keepfiles = "true|false" (default=false => don't keep files in harvest directory after storage in database)
	overwrite = "true|false" (default=false => don't store files already present in database)
	support-hits = "true|false" (default=true => use resultType=hits to get numberofrecords;
	                  should be set to false for ESRI because numberOfmatchingRecords are not returned)

	optional element constraint specifies a constraint (in cql_text) when harvesting records
	with the following optional attribute:
	language = "FILTER|CQL_TEXT" (default=FILTER => constraint language used)
-->
<hosts>
  <host id="LOCAL" harvest="no">
    <name>localhost</name>
    <url>http://localhost:8088/excat2/csw</url>
  </host>
</hosts>
END

# fix the base-paths
info "Fixing the serviceUrlBasePath definitions ..."
find WEB-INF/xsl/csw-schemas/eop -name \*.xsl -exec sed -e "/<xsl:variable *name=\"serviceUrlBasePath\"/s#select=\"[^\"]*\"#select=\"'$WMS_URL'\"#" -i {} \;

# repack the archive
zip "$_WAR" -ur *

popd

#======================================================================
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
    ProxyPass        $XCAT_URL_PATH ajp://127.0.0.1:8089$XCAT_URL_PATH
    ProxyPassReverse $XCAT_URL_PATH ajp://127.0.0.1:8089$XCAT_URL_PATH

    # XCT00_END - eXcat - Do not edit or remove this line!
.
wq
END
done

#-------------------------------------------------------------------------------
# restart apache to force the changes to take effect

service httpd restart
