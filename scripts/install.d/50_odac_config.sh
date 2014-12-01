#!/bin/sh
#
# configure ODA-OS ODA-Client
#
#======================================================================

. `dirname $0`/../lib_logging.sh
. `dirname $0`/../lib_apache.sh

info "Configuring ODA Client ... "

# NOTE: In ODA-OS, it is not expected to have mutiple instances of the Ingestion Engine

[ -z "$ODAOS_ODAC_HOME" ] && error "Missing the required ODAOS_ODAC_HOME variable!"
[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
#[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
#[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
#[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
#[ -z "$ODAOSTMPDIR" ] && error "Missing the required ODAOSTMPDIR variable!"

ODAOS_ODAC_URL="/oda"
HOSTNAME="$ODAOSHOSTNAME"
CONFIG_JSON="${ODAOS_ODAC_HOME}/config.json"
IE_BASE_URL="http://${HOSTNAME}/ingest/ManageScenario/"
LAYERS_URL="http://${HOSTNAME}/eoxs/eoxc"
QTMP_URL="http://${HOSTNAME}/q1/pq.html"

#======================================================================
# configuration

# define JQ filters
_F1=".ingestionEngineT5.baseUrl=\"$IE_BASE_URL\""
_F2=".mapConfig.dataconfigurl=\"$LAYERS_URL\""
_F3='del(.mapConfig.products)'
_F4=".orthoQualityConfig.qtmpUrl=\"$QTMP_URL\""

sudo -u "$ODAOSUSER" cp "$CONFIG_JSON" "$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" jq "$_F1|$_F2|$_F3|$_F4" >"$CONFIG_JSON" <"$CONFIG_JSON~" && \
sudo -u "$ODAOSUSER" rm -f "$CONFIG_JSON~"

#======================================================================
# Integration with the Apache web server

info "Setting ODA Client installation behind the Apache reverse proxy ..."

# locate proper configuration file (see also apache configuration)
{
    locate_apache_conf 80
    locate_apache_conf 443
} | while read CONF
do
    { ex "$CONF" || /bin/true ; } <<END
/ODAC00_BEGIN/,/ODAC00_END/de
/^[ 	]*<\/VirtualHost>/i
    # ODAC00_BEGIN - ODA Client - Do not edit or remove this line!

    # DREAM ODA Client
    Alias $ODAOS_ODAC_URL "$ODAOS_ODAC_HOME"
    <Directory "$ODAOS_ODAC_HOME">
            Options -MultiViews +FollowSymLinks
            AllowOverride None
            Order Allow,Deny
            Allow from all
    </Directory>

    # ODAC00_END - ODA Client - Do not edit or remove this line!
.
wq
END
done

#-------------------------------------------------------------------------------
# restart apache to force the changes to take effect

service httpd restart
