#!/bin/sh
#-------------------------------------------------------------------------------
#
# Project: DREAM - Task 5 - ODA-OS
# Purpose: reset hostname in the ODA-OS configuration
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2013 EOX IT Services GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies of this Software or works derived from this Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

#source common parts
. `dirname $0`/lib_common.sh
. `dirname $0`/lib_logging.sh

#-------------------------------------------------------------------------------

if [ "$1" == "-s" ]
then
    SCHEME="https://"
    PORT="443"
    shift
else
    SCHEME="http://"
    PORT="80"
fi

if [ -z "$1" ]
then
    echo "ERROR: $EXENAME: Missing the required host name!" >&2
    echo "USAGE: $EXENAME [-s] <hostname>" >&2
    echo "OPTIONS:" >&2
    echo "    -s  Force HTTPS instead of the default plain HTTP URL." >&2
    exit 1
fi

HOSTNAME="$1"

info "Setting the services' base URL to: ${SCHEME}${HOSTNAME}:${PORT}"

[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$ODAOS_IE_HOME" ] && error "Missing the required ODAOS_IE_HOME variable!"
[ -z "$ODAOS_DQ_HOME" ] && error "Missing the required ODAOS_DQ_HOME variable!"
[ -z "$ODAOS_ODAC_HOME" ] && error "Missing the required ODAOS_ODAC_HOME variable!"

#-------------------------------------------------------------------------------
# Ingestion Engine
INSTANCE="ingestion"
INSTROOT="$ODAOS_IE_HOME"
IE_SETTINGS="${INSTROOT}/${INSTANCE}/settings.py"

# set the allowed hosts
sudo -u "$ODAOSUSER" ex "$IE_SETTINGS" <<END
1,\$s/\(^ALLOWED_HOSTS[	 ]*=[	 ]*\).*/\1['$HOSTNAME','127.0.0.1','::1']/
wq
END

service ingeng restart

#-------------------------------------------------------------------------------
# EOxServer - set the service url

INSTANCE="eoxs"
INSTROOT="$ODAOSROOT"
EOXSCONF="${INSTROOT}/${INSTANCE}/${INSTANCE}/conf/eoxserver.conf"
EOXSTNGS="${INSTROOT}/${INSTANCE}/${INSTANCE}/settings.py"

sudo -u "$ODAOSUSER" ex "$EOXSCONF" <<END
/^[	 ]*http_service_url[	 ]*=/s;\(^[	 ]*http_service_url[	 ]*=\).*;\1${SCHEME}${HOSTNAME}/${INSTANCE}/ows?;
wq
END

# set the allowed hosts
sudo -u "$ODAOSUSER" ex "$EOXSTNGS" <<END
1,\$s/\(^ALLOWED_HOSTS[	 ]*=[	 ]*\).*/\1['$HOSTNAME','127.0.0.1','::1']/
wq
END

#-------------------------------------------------------------------------------
# ODA Client

CONFIG_JSON="${ODAOS_ODAC_HOME}/config.json"
IE_BASE_URL="${SCHEME}${HOSTNAME}/ingest/ManageScenario/"
LAYERS_URL="${SCHEME}${HOSTNAME}/eoxs/eoxc"
QTMP_URL="${SCHEME}${HOSTNAME}/q1/pq.html"

# define JQ filters
_F1=".ingestionEngineT5.baseUrl=\"$IE_BASE_URL\""
_F2=".mapConfig.dataconfigurl=\"$LAYERS_URL\""
_F4=".orthoQualityConfig.qtmpUrl=\"$QTMP_URL\""

sudo -u "$ODAOSUSER" cp "$CONFIG_JSON" "$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" jq "$_F1|$_F2|$_F4" >"$CONFIG_JSON" <"$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" rm -f "$CONFIG_JSON~"

#-------------------------------------------------------------------------------

service httpd restart

#-------------------------------------------------------------------------------
# Data Quality subsystem (if installed)

if [ -f '/etc/init.d/tomcat-dq' ]
then
    service tomcat-dq stop

    DQ_CFG="$ODAOS_DQ_HOME/q2/local/tomcat/webapps/constellation/WEB-INF/constellation.properties"
    ex "$DQ_CFG" <<END
s#\(^[ 	]*services.url=\)[a-zA-Z0-9]*://[^/\?\#]*\(.*\)#\1${SCHEME}${HOSTNAME}:${PORT}\2#
wq
END

    service tomcat-dq start
fi

#-------------------------------------------------------------------------------
# eXcat2 catalogue (if installed)

EXCAT2_CAPAB_XML="/usr/share/tomcat/webapps/excat2/WEB-INF/xml/capabilities.xml"
EXCAT2_EOP_XSL="/usr/share/tomcat/webapps/excat2/WEB-INF/xsl/csw-schemas/eop"
WMS_URL="${SCHEME}${HOSTNAME}:${PORT}/eoxs/ows"

if [ -f "$EXCAT2_CAPAB_XML" ]
then

  { ex "$EXCAT2_CAPAB_XML" || /bin/true ; } <<END
g/\s\+<ows:Get/s#xlink:href="https\=://\([^/]*\)\(/\=.*\)"#xlink:href="${SCHEME}${HOSTNAME}:${PORT}\2"#
g/\s\+<ows:Post/s#xlink:href="https\=://\([^/]*\)\(/\=.*\)"#xlink:href="${SCHEME}${HOSTNAME}:${PORT}\2"#
wq
END

    find "$EXCAT2_EOP_XSL" -name \*.xsl \
        -exec sed -e "/<xsl:variable *name=\"serviceUrlBasePath\"/s#select=\"[^\"]*\"#select=\"'$WMS_URL'\"#" -i {} \;

  service tomcat restart
fi
