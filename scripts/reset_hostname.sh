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

if [ "$#" -lt "1" ] 
then 
    echo "ERROR: $EXENAME: Missing the required host name!" >&2 
    echo "USAGE: $EXENAME <hostname>" >&2 
    exit 1 
fi 

info "Setting the service hostname to: $1"

HOSTNAME="$1"

#-------------------------------------------------------------------------------
# EOxServer set the service url 

INSTANCE="eoxs"
INSTROOT="$ODAOSROOT"
EOXSCONF="${INSTROOT}/${INSTANCE}/${INSTANCE}/conf/eoxserver.conf"
EOXSTNGS="${INSTROOT}/${INSTANCE}/${INSTANCE}/settings.py"

sudo -u "$ODAOSUSER" ex "$EOXSCONF" <<END
/^[	 ]*http_service_url[	 ]*=/s;\(^[	 ]*http_service_url[	 ]*=\).*;\1http://${HOSTNAME}/${INSTANCE}/ows;
wq
END

# set the allowed hosts
sudo -u "$ODAOSUSER" ex "$EOXSTNGS" <<END
1,\$s/\(^ALLOWED_HOSTS[	 ]*=[	 ]*\).*/\1['$HOSTNAME']/
wq
END

#-------------------------------------------------------------------------------
# ODA Client 

CONFIG_JSON="${ODAOS_ODAC_HOME}/config.json"
IE_BASE_URL="http://${HOSTNAME}/ingest/ManageScenario/"
LAYERS_URL="http://${HOSTNAME}/eoxs/eoxc"

# define JQ filters 
_F1=".ingestionEngineT5.baseUrl=\"$IE_BASE_URL\""
_F2=".mapConfig.dataconfigurl=\"$LAYERS_URL\""

sudo -u "$ODAOSUSER" cp "$CONFIG_JSON" "$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" jq "$_F1|$_F2" >"$CONFIG_JSON" <"$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" rm -f "$CONFIG_JSON~"

#-------------------------------------------------------------------------------
service httpd restart
