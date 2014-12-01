#!/bin/sh
#
# configure Data Quality subsystem
#
#======================================================================

. `dirname $0`/../lib_logging.sh
. `dirname $0`/../lib_apache.sh

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
DQ_PROXY_PORT=8280
ODAOS_PORT=80
DQ_SERVICE="tomcat-dq"

EOXS_ID2PATH_URL="http://127.0.0.1/eoxs/id2path?id="
IE_ADDPRODUCT_URL="http://127.0.0.1:8000/ingest/addProduct/addProduct"
IE_UPDATEMD_URL="http://127.0.0.1:8000/ingest/uqmd/updateMD"

if [ ! -d "$ODAOS_DQ_HOME" ]
then
    error "Data Quality subsytem does not seem to be installed in: $ODAOS_DQ_HOME"
    error "Data Quality subsytem configuration is terminated."
    exit 0
fi

# try to stop the service if it is running
[ -f "/etc/init.d/$DQ_SERVICE" ] && service "$DQ_SERVICE" stop || :

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

DQ_KEYSTORE="$ODAOS_DQ_HOME/q2/config/truststore.jks"
DQ_SERVER_CERT="$ODAOS_DQ_HOME/q2/services.spotimage.fr.pem"
DQ_INSTALLER="$ODAOS_DQ_HOME/q2/install.sh"

[ ! -f "$DQ_KEYSTORE" ] || rm -fv "$DQ_KEYSTORE"
[ -f "$DQ_INSTALLER" ] || error "Cannot find the '$DQ_INSTALLER' installer!"

# NOTE: The install script requires the working directory
#       to be the same as the location of the script.
(
    cd "`dirname "$DQ_INSTALLER" `"
    sudo -u "$DQ_USER" sh "./`basename "$DQ_INSTALLER" `" \
            -t "$DQ_PROXY_HOST" -u "$DQ_PROXY_PORT" \
            -j "http" -k "$ODAOSHOSTNAME" -l "$ODAOS_PORT" \
            -p "$DQ_SERVICE_HOST" -q "$DQ_SERVICE_PORT" -r "$DQ_WPS_CONTEXT" \
            -a "$DQ_LOG_DIR" -b "$DQ_DATA_DIR" \
            -z "$DQ_SERVER_CERT" -v "$DQ_USER"
)

# fix the configuration of the interfaces
sudo -u "$DQ_USER" ex "$ODAOS_DQ_HOME/q2/config/_.dream/dream.properties" <<END
1,\$s#^\([ 	]*ODA_ID2PATH_URL[ 	]*=\).*\$#\1$EOXS_ID2PATH_URL#
1,\$s#^\([ 	]*ODA_ADDPRODUCT_URL[ 	]*=\).*\$#\1$IE_ADDPRODUCT_URL#
1,\$s#^\([ 	]*ODA_UPDATEMD_URL[ 	]*=\).*\$#\1$IE_UPDATEMD_URL#
wq
END

#======================================================================
# start the service

info "Data Quality subsytem service initialization ..."

DQ_INIT_SRC="$ODAOS_DQ_HOME/q2/$DQ_SERVICE"
DQ_INIT="/etc/init.d/$DQ_SERVICE"

#sudo -u "$DQ_USER" ex "$DQ_INIT_SRC" <<END
#1,\$s/^\([ 	]*CATALINA_USER[ 	]*=\).*\$/\1"$DQ_USER"/
#wq
#END
#cp -fv "$DQ_INIT_SRC" "$DQ_INIT"

[ -f "$DQ_INIT" ] && mv -fv "$DQ_INIT" "$DQ_INIT.bak"
[ -f "$DQ_INIT" ] && rm -fv "$DQ_INIT"

cat >"$DQ_INIT" <<END
#!/bin/sh
#
# $DQ_SERVICE	Tomcat - Data Quality Proxy
#
# chkconfig: - 80 20
# description: starts, stops, and restarts the tomcat instance
#
# NOTE: This init script is created by the DREAM ODA-OS installation script.
# NOTE: The service must be explicitely enabled by 'chkconfig $DQ_SERVICE on' command.
#
### BEGIN INIT INFO
# Provides: $DQ_SERVICE
# Required-Start: \$local_fs \$remote_fs \$network \$named
# Required-Stop: \$local_fs \$remote_fs \$network
# Default-Stop: 0 1 2 3 4 5 6
# Default-Start:
# Short-Description: Starts, stops, and restarts the ngEO donwload manager
# Description: Starts, stops, and restarts the ngEO donwload manager
### END INIT INFO

. /etc/rc.d/init.d/functions

CATALINA_USER="$DQ_USER"
CATALINA_HOME="$ODAOS_DQ_HOME/q2/local/tomcat"
CATALINA_SH="\${CATALINA_HOME}/bin/catalina.sh"
CATALINA_PID="\${CATALINA_HOME}/var/catalina.pid"
SHUTDOWN_WAIT=20

prog="$DQ_SERVICE"
pidfile="\$CATALINA_PID"

status()
{
    if [ -f "\${pidfile}" ]
    then
        pid="\$( cat "\${pidfile}" )"
        if ps p "\$pid" >/dev/null
        then
            echo \$"\${prog} (pid \$pid) is running ..."
            return 0
        else
            echo \$"\${prog} is dead but pid file exists"
            return 1
        fi
    else
        echo \$"\${prog} is stopped"
        return 2
    fi
}

start()
{
    MSG=\$( status )
    case "\$?" in
        0 )
            echo \$"\$MSG" ;
            return 0
            ;;
        1 )
            echo \$"WARNING: \$MSG"
            rm -fv "\$pidfile"
            ;;
    esac

    echo \$"Starting tomcat"
    runuser -l \$CATALINA_USER -c "\${CATALINA_SH} start"

    MSG=\$( status )
    case "\$?" in
        0 ) echo \$"OK" ; return 0 ;;
        1 | 2 ) echo \$"FAILED" ; return 1 ;;
    esac
}

stop()
{
    MSG=\$( status )
    case "\$?" in
        2 )
            echo \$"\$MSG" ;
            return 0
            ;;
        1 )
            echo \$"WARNING: \$MSG"
            rm -fv "\$pidfile"
            return 0
            ;;
    esac

    pid="\$( cat "\${pidfile}" )"

    echo \$"Stopping Tomcat"
    runuser -l \$CATALINA_USER -c "\${CATALINA_SH} stop"

    count_max="\${SHUTDOWN_WAIT:-5}"
    count=0

    while [ \$count -le "\$count_max" ] && ps p "\$pid" >/dev/null 2>&1
    do
        echo \$"Waiting for the processes to exit ...";
        sleep 1
        let count=\$count+1;
    done

    if ps p "\$pid" >/dev/null 2>&1
    then
        echo \$"Killing the processes which didn't stop after \$SHUTDOWN_WAIT seconds!"
        kill -9 \$pid
        sleep 1
    fi

    MSG=\$( status )
    case "\$?" in
        2 ) echo \$"OK" ; return 0 ;;
        1 ) echo \$"OK" ; rm -fv "\$pidfile" ; return 0 ;;
        0 ) echo \$"FAILED" ; return 1 ;;
    esac
}


case \$1 in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  status)
    status
    ;;
esac
exit 0
END
chmod +x "$DQ_INIT"

chkconfig "$DQ_SERVICE" on
service "$DQ_SERVICE" start

#======================================================================
# Integration with the Apache web server

info "Setting Data Quality proxy behind the Apache reverse proxy ..."

# locate proper configuration file (see also apache configuration)
{
    locate_apache_conf 80
    locate_apache_conf 443
} | while read CONF
do
    # delete any previous configuration and write a new one
    { ex "$CONF" || /bin/true ; } <<END
/DQ00_BEGIN/,/DQ00_END/de
/^[ 	]*<\/VirtualHost>/i
    # DQ00_BEGIN - Data Quality Proxy - Do not edit or remove this line!

    # improvised Q1 client
    Alias /q1 "/srv/odaos/data-quality/q1"
    <Directory "/srv/odaos/data-quality/q1">
            Options -MultiViews +FollowSymLinks
            AllowOverride None
            Order Allow,Deny
            Allow from all
            Header set Access-Control-Allow-Origin "*"
    </Directory>

    # reverse proxy to the Data Qaulity Proxy

    ProxyPass        /constellation http://$DQ_PROXY_HOST:$DQ_PROXY_PORT/constellation
    ProxyPassReverse /constellation http://$DQ_PROXY_HOST:$DQ_PROXY_PORT/constellation

    # DQ00_END - Data Quality Proxy - Do not edit or remove this line!
.
wq
END
done

# restart apache to force the changes to take effect
service httpd restart
