#!/bin/sh 
#
# configure ODA-OS ingestion engine 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Configuring Ingestion Engine ... "

#======================================================================
# NOTE: In ODA-OS, it is not expected to have mutiple instances of the EOxServer

[ -z "$ODAOS_IEAS_HOME" ] && error "Missing the required ODAOS_IEAS_HOME variable!"
[ -z "$ODAOS_DM_HOME" ] && error "Missing the required ODAOS_DM_HOME variable!"
[ -z "$ODAOS_IE_HOME" ] && error "Missing the required ODAOS_IE_HOME variable!"
#[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
#[ -z "$ODAOSTMPDIR" ] && error "Missing the required ODAOSTMPDIR variable!"
export ODAOSLOGDIR=${ODAOSLOGDIR:-/var/log/odaos}

#HOSTNAME="$ODAOSHOSTNAME"
INSTANCE="ingestion"
INSTROOT="$ODAOS_IE_HOME"
#
SETTINGS="${INSTROOT}/${INSTANCE}/settings.py"
#INSTSTAT_URL="/${INSTANCE}_static" # DO NOT USE THE TRAILING SLASH!!!
#INSTSTAT_DIR="${INSTROOT}/${INSTANCE}/${INSTANCE}/static"
#WSGI="${INSTROOT}/${INSTANCE}/${INSTANCE}/wsgi.py"
INGESTION_CONFIG="${INSTROOT}/ingestion_config.json"
MNGCMD="${INSTROOT}/manage.py"
#
#DBENGINE="django.contrib.gis.db.backends.postgis"
#DBNAME="eoxs_${INSTANCE}"
#DBUSER="eoxs_admin_${INSTANCE}"
#DBPASSWD="${INSTANCE}_admin_eoxs"
#DBHOST=""
#DBPORT=""
#
#PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
#
#EOXSLOG="${ODAOSLOGDIR}/eoxserver.log"
#EOXSCONF="${INSTROOT}/${INSTANCE}/${INSTANCE}/conf/eoxserver.conf"
#EOXSURL="http://${HOSTNAME}/${INSTANCE}/ows"

#-------------------------------------------------------------------------------
# configuration 

# ingestion_config.json 
sudo -u "$ODAOSUSER" ex "$INGESTION_CONFIG" <<END
1,\$s:\("DownloadManagerDir"[	 ]*\:[	 ]*"\).*\("[	 ]*,\):\1$ODAOS_DM_HOME\2:
wq
END

# settings.py 
sudo -u "$ODAOSUSER" ex -V "$SETTINGS" <<END
1,\$s:^\(LOGGING_DIR[	 ]*=[	 ]*\).*$:\1"$ODAOSLOGDIR":
1,\$s:^\(IE_SCRIPTS_DIR[	 ]*=[	 ]*\).*$:\1"$ODAOS_IEAS_HOME":
wq
END

#-------------------------------------------------------------------------------
# Django syncdb (without interactive prompts) 

info "Initializing EOxServer instance '${INSTANCE}' ..."

# collect static files (do not use the -l option!)
sudo -u "$ODAOSUSER" python "$MNGCMD" collectstatic --noinput

# setup new database 
sudo -u "$ODAOSUSER" python "$MNGCMD" syncdb --noinput 

#======================================================================
# wrapper script

#IE_CONSOLE_LOG="/dev/null"
IE_CONSOLE_LOG="$ODAOSLOGDIR/ingeng_console.log"
IE_DAEMON="${INSTROOT}/start-ie-as-daemon.sh"

info "Cretating the Ingestion Engine's daemon start-up script: $IE_DAEMON"

# make the necessary changes
cat >"$IE_DAEMON" <<END
#!/bin/sh
#
# Ingestion Engine start-up script 
#
IE_HOME="\$( dirname \$0 )"
IE_HOME="\$( cd \$IE_HOME ; pwd ; )"
IE_ADDR=\${IE_ADDR:-0.0.0.0}
IE_PORT=\${IE_PORT:-8000}
IE_OPT="--nothreading --noreload \\"\$IE_ADDR:\$IE_PORT\\""

if [ -z "\$IE_USER" ]
then 
    EXEC="/bin/sh"
else 
    EXEC="runuser "\$IE_USER" -s /bin/sh"
fi

PID=\$( \$EXEC -c "ulimit -S -c 0 ; cd \\"\$IE_HOME\\" ; /usr/bin/python $MNGCMD runserver \$IE_OPT >'$IE_CONSOLE_LOG' 2>&1 & echo \\\$!" )

# check whether the daemon is still alive 
sleep 2 
[ -z "\$PID" ] && exit 1 
ps p "\$PID" >/dev/null 2>&1 || exit 1 

# IE_PIDFILE optionally contains file-name where the daemons PID shall be written.
if [ -n "\$IE_PIDFILE" ]
then
    echo "\$PID" > "\$IE_PIDFILE"
else
    echo "Daemon started. PID=\$PID"
fi
END

chown "$ODAOSUSER:$ODAOSGROUP" "$IE_DAEMON"
chmod 0755 "$IE_DAEMON" 

#======================================================================
# init script  

IE_INIT="/etc/init.d/ingeng"
IE_PIDFILE="/var/run/ingend.pid"
IE_LOCK="/var/lock/subsys/ingeng"

info "Cretating the Ingestion Engine's init script: $IE_INIT"

cat >"$IE_INIT" <<END 
#!/bin/sh 
# 
# ingeng        Ingestion Engine 
#
# chkconfig: - 85 15
# description: starts, stops, and restarts the donwload manager 
#
# NOTE: This init script is created by the DREAM ODA-OS installation script.
# NOTE: The service must be explicitely enabled by 'chkconfig ingeng on' command.
#
# pidfile: $IE_PIDFILE
# lockfile: $IE_LOCK
#
### BEGIN INIT INFO
# Provides: ngeo-dm 
# Required-Start: \$local_fs \$remote_fs \$network \$named
# Required-Stop: \$local_fs \$remote_fs \$network
# Default-Stop: 0 1 2 3 4 5 6
# Default-Start: 
# Short-Description: Starts, stops, and restarts the ngEO donwload manager 
# Description: Starts, stops, and restarts the ngEO donwload manager
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

prog="ingeng"
user="$ODAOSUSER"
ingengd="$IE_DAEMON"
pidfile="$IE_PIDFILE"
lockfile="$IE_LOCK"
timeout="5"


# create PID-file directory if it does not exists 
[ -d "\$(dirname \${pidfile})" ] || mkdir -p "\$(dirname \${pidfile})"

#---------
ie_status()
{ 
    if [ -f "\${pidfile}" ]
    then 

        pid="\$( cat "\${pidfile}" )"

        if ps p "\$pid" >/dev/null 
        then 
            echo $"\${prog} (pid \$pid) is running ..."
            return 0 
        else 
            echo $"\${prog} is dead but pid file exists"
            return 1
        fi 

    elif [ -f "\${lockfile}" ]
    then 

        echo $"\${prog} is dead but subsys locked" 
        return 2 

    else 

        echo $"\${prog} is stopped"
        return 3 

    fi 
} 

#---------
ie_start() 
{ 
    # parameters of the daemon's statup script
    export IE_PIDFILE="\$pidfile"
    export IE_USER="\$user"

    # check status and write message if something's wrong 
    MSG=\$( ie_status )
    case "\$?" in 
        0 | 1 | 2 ) echo $"WARNING: \$MSG" ;; 
    esac 

    echo -n \$"Starting \$prog: "

    # start the daemon 
    daemon --pidfile=\${pidfile} \${ingengd}
    RETVAL=\$?

    echo
    [ \$RETVAL = 0 ] && touch \${lockfile}
    return \$RETVAL
} 

#---------
ie_stop() 
{ 
    # check status and write message if something's wrong 
    MSG=\$( ie_status )
    case "\$?" in 
        1 | 2 | 3 ) echo $"WARNING: \$MSG" ;; 
    esac 

    echo -n \$"Stopping \$prog: "
    killproc -p \${pidfile} -d \${timeout} \${ingengd}
    RETVAL=\$?
    echo 
    [ \$RETVAL = 0 ] && rm -f \${lockfile} \${pidfile}
} 

#---------
ie_reset() 
{
    # check status and write message if something's wrong 
    MSG=\$( ie_status )
    case "\$?" in 
        0 | 1 | 2 )
            echo $"WARNING: \$MSG" 
            echo $"ERROR: Stop \$prog properly before the DB reset!"
            return 3 
            ;; 
    esac 
    echo -n \$"Resetting \$prog: "
}

#---------
case "\$1" in 

    start) ie_start ;; 

    stop) ie_stop ;; 

    restart) ie_stop ; ie_start ;; 

    status)
        ie_status 
        RETVAL=\$?
        ;; 

    reset) 
        ie_reset
        RETVAL=\$?
        ;; 
    *) 
        echo \$"Usage: \$prog {start|stop|restart|reset|status}"
        RETVAL=2
        ;;
esac

exit \$RETVAL
END

chmod 0755 "$IE_INIT" 

#add service for managemnt by chkconfig
chkconfig --add ingeng

#======================================================================
# make the donwload manager enabled permanently and start the service 

info "Enabling the download manager's service ..."
chkconfig ingeng on 
service ingeng restart
