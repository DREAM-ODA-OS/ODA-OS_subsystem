#!/bin/sh
#
# configure Data Quality subsystem
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Configuring Data Quality subsytem ... "

#======================================================================

[ -z "$ODAOS_DQ_HOME" ] && error "Missing the required ODAOS_DQ_HOME variable!"
[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"
[ -z "$ODAOSDATADIR" ] && error "Missing the required ODAOSDATADIR variable!"

DQ_USER="$ODAOSUSER"
DQ_GROUP="$ODAOSGROUP"
DQ_LOG_DIR="$ODAOSLOGDIR/data-quality"
DQ_DATA_DIR="$ODAOSDATADIR/data-quality"
DQ_WPS_CONTEXT="ool-wps-server"
DQ_SERVICE_HOST="services.spotimage.fr"
DQ_SERVICE_PORT=8443
DQ_PROXY_HOST="127.0.0.1"
DQ_PROXY_PORT=8080
ODAOS_PORT=80
DQ_SERVICE="tomcat-dq"

if [ ! -d "$ODAOS_DQ_HOME" ]
then
    error "Data Quality subsytem does not seem to be installed in: $ODAOS_DQ_HOME"
    error "Data Quality subsytem configuration is terminated."
    exit 0
fi

#======================================================================

info "Preparing the log directory: $DQ_LOG_DIR"

[ -d "$DQ_LOG_DIR" -o -f "$DQ_LOG_DIR" ] && rm -vfR "$DQ_LOG_DIR"

mkdir -vp "$DQ_LOG_DIR"
chown -v "$DQ_USER:$DQ_GROUP" "$DQ_LOG_DIR"
chmod -v 0755 "$DQ_LOG_DIR"

info "Preparing the data directory: $DQ_DATA_DIR"

[ -d "$DQ_DATA_DIR" -o -f "$DQ_DATA_DIR" ] && rm -vfR "$DQ_DATA_DIR"

mkdir -vp "$DQ_DATA_DIR"
chown -v "$DQ_USER:$DQ_GROUP" "$DQ_DATA_DIR"
chmod -v 0755 "$DQ_DATA_DIR"

#======================================================================

info "Data Quality subsytem configuration ..."

DQ_INSTALLER="$ODAOS_DQ_HOME/q2/install.sh"

[ -f "$DQ_INSTALLER" ] || error "Cannot find the '$DQ_INSTALLER' installer!"

# NOTE: The install script requires the working directory
#       to be the same as the location of the script.
(
    cd "`dirname "$DQ_INSTALLER" `"
    sudo -u "$DQ_USER" sh -x "./`basename "$DQ_INSTALLER" `" \
            -t "$DQ_PROXY_HOST" -u "$DQ_PROXY_PORT" \
            -j "http" -k "$ODAOSHOSTNAME" -l "$ODAOS_PORT" \
            -p "$DQ_SERVICE_HOST" -q "$DQ_SERVICE_PORT" -r "$DQ_WPS_CONTEXT" \
            -a "$DQ_LOG_DIR" -b "$DQ_DATA_DIR"
)

#======================================================================
# start the service

info "Data Quality subsytem service initialization ..."
DQ_STARTUP_SRC="$ODAOS_DQ_HOME/q2/$DQ_SERVICE"
sudo -u "$DQ_USER" ex -V "$DQ_STARTUP_SRC" <<END
1,\$s/^\(CATALINA_USER=\).*$/\1"$DQ_USER"/
wq
END

cp -fv "$DQ_STARTUP_SRC" "/etc/init.d"

chkconfig "$DQ_SERVICE" on
service "$DQ_SERVICE" restart

