#!/bin/sh
#
# configure Data Quality subsystem 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Configuring Data Quality subsytem ... "

#======================================================================

DQ_WPS_CONTEXT="ool-wps-server"
DQ_SERVICE_HOST="services.spotimage.fr"
DQ_SERVICE_PORT=8443
DQ_PROXY_HOST="127.0.0.1"
DQ_PROXY_PORT=8080
ODAOS_PORT=80
DQ_SERVICE="tomcat7-dq"

[ -z "$ODAOS_DQ_HOME" ] && error "Missing the required ODAOS_DQ_HOME variable!"
[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"

if [ ! -d "$ODAOS_DQ_HOME" ] 
then 
    error "Data Quality subsytem does not seem to be installed in: $ODAOS_DQ_HOME"
    error "Data Quality subsytem configuration is terminated."
    exit 0 
fi

#======================================================================

info "Data Quality subsytem configuration ..."

[ -f "$ODAOS_DQ_HOME/install.sh" ] || error "Cannot find the '$ODAOS_DQ_HOME/install.sh' installer!"


sudo -u "$ODAOSUSER" sh "$ODAOS_DQ_HOME/install.sh" "$DQ_PROXY_HOST" "$DQ_PROXY_PORT" \
        "$ODAOSHOSTNAME" "$ODAOS_PORT" "$DQ_SERVICE_HOST" "$DQ_SERVICE_PORT" "$DQ_WPS_CONTEXT"

#======================================================================
# start the service 

info "Data Quality subsytem service initialization ..."

cp "$ODAOS_DQ_HOME/$DQ_SERVICE" "/etc/init.d/$DQ_SERVICE"

chkconfig "$DQ_SERVICE" on 
service "$DQ_SERVICE" restart

