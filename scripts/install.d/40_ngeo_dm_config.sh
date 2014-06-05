#!/bin/sh
#
# configure ngEO downaload manager
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Configuring ngEO Download Manager ... "

#======================================================================

[ -z "$ODAOS_DM_HOME" ] && error "Missing the required ODAOS_DM_HOME variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
[ -z "$ODAOSTMPDIR" ] && error "Missing the required ODAOSTMPDIR variable!"

DM_USER="$ODAOSUSER"
DM_GROUP="$ODAOSGROUP"

# stop the service if already running
service ngeo-dm stop || :

#======================================================================
# fix the logs' locations

DM_CONF_LOG="$ODAOS_DM_HOME/conf/log4j.xml"

info "Setting the location of the download manager's logfiles to $ODAOSLOGDIR"
sudo -u "$ODAOSUSER" ex "$DM_CONF_LOG" <<END
1,\$s:\${DM_HOME}/logs:${ODAOSLOGDIR}:ge
wq
END

#======================================================================
# java wrapper

#DM_CONSOLE_LOG="/dev/null"
DM_CONSOLE_LOG="$ODAOSLOGDIR/ngeo-dm_console.log"

DM_START="$ODAOS_DM_HOME/start-dm.sh"
DM_DAEMON="$ODAOS_DM_HOME/start-dm-as-daemon.sh"

info "Cretating the download manager's daemon start-up script: $DM_DAEMON"

# copy the source start-up script
sudo -u "$ODAOSUSER" cp -fv "$DM_START" "$DM_DAEMON"

# make the port number configurable for older versions of the DM
[ -n "`grep 'DM_PORT=' "$DM_DAEMON"`" ] && sudo -u "$ODAOSUSER" ex "$DM_DAEMON" <<END
2a
# if DM_PORT is set use it to define the port on which the DM's web server binds to (defaults to 8082)
DM_PORT=\${DM_PORT:-8082}

.
wq
END

# edit the daemon start-up scripts using the ex voodoo
sudo -u "$ODAOSUSER" ex "$DM_DAEMON" <<END
2a
# If DM_CONSOLE_LOG is set it defines a log file where the console
#  output is caught (defaults to '/dev/null'.
DM_CONSOLE_LOG="\${DM_CONSOLE_LOG:-/dev/null}"

# If DM_USER is set, it is used as the owner of the daemon process.
EXEC="/bin/sh"
[ -n "\$DM_USER" ] && EXEC="runuser "\$DM_USER" -s \$EXEC"

# clear the session log if necessary
[ "/dev/null" != "\$DM_CONSOLE_LOG" ] && rm -f "\$DM_CONSOLE_LOG"

.
/[ 	\/]java[ 	].*download-manager-webapp.*\.war/
.s/\$DM_PORT/"\$DM_PORT"/ge
.s/8082/"\$DM_PORT"/ge
.s/"/\\\\"/ge
.s:^.*$:PID=\$( \$EXEC -c "ulimit -S -c 0 ; cd \\\\"\$DM_HOME\\\\" ; nohup & <\&- >\\\\"\$DM_CONSOLE_LOG\\\\" 2>\&1 \& echo \\\\\$!" ):e
\$a

# check whether the daemon is still alive
sleep 2
[ -z "\$PID" ] && exit 1
ps p "\$PID" >/dev/null 2>&1 || exit 1

# DM_PIDFILE optionally contains a file-name where the daemons PID shall be written.
if [ -n "\$DM_PIDFILE" ]
then
    echo "\$PID" > "\$DM_PIDFILE"
else
    echo "Daemon started. PID=\$PID"
fi
.
wq
END

chmod 0755 "$DM_DAEMON"

#======================================================================
# init script

DM_INIT="/etc/init.d/ngeo-dm"
DM_PIDFILE="/var/run/ngeo-dm.pid"
DM_LOCK="/var/lock/subsys/ngeo-dm"

info "Cretating the download manager's init script: $DM_INIT"

cat >"$DM_INIT" <<END
#!/bin/sh
#
# ngeo-dm      ngEO Download Manager
#
# chkconfig: - 85 15
# description: starts, stops, and restarts the donwload manager
#
# NOTE: This init script is created by the DREAM ODA-OS installation script.
# NOTE: The service must be explicitely enabled by 'chkconfig ngeo-dm on' command.
#
# pidfile: $DM_PIDFILE
# lockfile: $DM_LOCK
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

prog="ngeo-dm"
user="$DM_USER"
ngeo_dm="$DM_DAEMON"
ngeo_dm_db="$ODAOS_DM_HOME/hsqldb"
pidfile="$DM_PIDFILE"
lockfile="$DM_LOCK"
console_log="$DM_CONSOLE_LOG"
timeout="5"


# create PID-file directory if it does not exists
[ -d "\$(dirname \${pidfile})" ] || mkdir -p "\$(dirname \${pidfile})"

#---------
dm_status()
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
dm_start()
{
    # parameters of the daemon's statup script
    export DM_PIDFILE="\$pidfile"
    export DM_USER="\$user"
    export DM_CONSOLE_LOG="\$console_log"

    # check status and write message if something's wrong
    MSG=\$( dm_status )
    case "\$?" in
        0 | 1 | 2 ) echo $"WARNING: \$MSG" ;;
    esac

    echo -n \$"Starting \$prog: "

    # start the daemon
    daemon --pidfile=\${pidfile} \${ngeo_dm}
    RETVAL=\$?

    echo
    [ \$RETVAL = 0 ] && touch \${lockfile}
    return \$RETVAL
}

#---------
dm_stop()
{
    # check status and write message if something's wrong
    MSG=\$( dm_status )
    case "\$?" in
        1 | 2 | 3 ) echo $"WARNING: \$MSG" ;;
    esac

    echo -n \$"Stopping \$prog: "
    killproc -p \${pidfile} -d \${timeout} \${ngeo_dm}
    RETVAL=\$?
    echo
    [ \$RETVAL = 0 ] && rm -f \${lockfile} \${pidfile}
}

#---------
dm_reset()
{
    # check status and write message if something's wrong
    MSG=\$( dm_status )
    case "\$?" in
        0 | 1 | 2 )
            echo $"WARNING: \$MSG"
            echo $"ERROR: Stop \$prog properly before the DB reset!"
            return 3
            ;;
    esac
    echo -n \$"Resetting \$prog: "

    if [ -d "\${ngeo_dm_db}" ]
    then
        if rm -fvR "\${ngeo_dm_db}"/*
        then
            echo DONE
            return 0
        else
            echo FAILED
            return 1
        fi
    else
        echo $"WARNING: \${ngeo_dm_db} seems to be reset alredy."
        echo FAILED
        return 2
    fi
}

#---------
case "\$1" in

    start) dm_start ;;

    stop) dm_stop ;;

    restart) dm_stop ; dm_start ;;

    status)
        dm_status
        RETVAL=\$?
        ;;

    reset)
        dm_reset
        RETVAL=\$?
        ;;
    *)
        echo \$"Usage: \$prog {start|stop|restart|reset|status}"
        RETVAL=2
        ;;
esac

exit \$RETVAL
END

chmod 0755 "$DM_INIT"

#add service for managemnt by chkconfig
chkconfig --add ngeo-dm

#======================================================================
# set the default downaload location

DM_DOWNLOAD_DIR="$ODAOSTMPDIR/ngeo-dm"

info "Setting the default donwload location to $DM_DOWNLOAD_DIR"

DM_CONFIG0="$ODAOS_DM_HOME/conf/userModifiableSettingsPersistentStore.properties"
DM_CONFIG1="$ODAOS_DM_HOME/conf/user-modifiable-settings.properties"

[ -f "$DM_CONFIG0" ] && DM_CONFIG="$DM_CONFIG0"
[ -f "$DM_CONFIG1" ] && DM_CONFIG="$DM_CONFIG1"

[ -z "$DM_CONFIG" ] && error "Cannot find the configuration file! FILE=$DM_CONFIG1"

# make the necessary changes
sudo -u "$ODAOSUSER" ex "$DM_CONFIG" <<END
1,\$s:\\r::ge
1,\$s:^[ 	]*\\(DM_FRIENDLY_NAME\\)[ 	]*=.*\$:\1=T5IngestionEngineDM:
1,\$s:^[ 	]*\\(BASE_DOWNLOAD_FOLDER_ABSOLUTE\\)[ 	]*=.*\$:\1=$DM_DOWNLOAD_DIR:
wq
END

#======================================================================
# make sure the directory exists and has the proper permissions

mkdir -v -p "$DM_DOWNLOAD_DIR"
chown -v "$ODAOSUSER:$ODAOSGROUP" "$DM_DOWNLOAD_DIR"
chmod -v 0775 "$DM_DOWNLOAD_DIR"

# clean the previous data
rm -fR "$DM_DOWNLOAD_DIR"/*

#======================================================================
# create the HSQLDB database directory with the proper permissions

DM_DBDIR="$ODAOS_DM_HOME/hsqldb"

mkdir -v -p "$DM_DBDIR"
chown -v "$ODAOSUSER:$ODAOSGROUP" "$DM_DBDIR"
chmod -v 0775 "$DM_DBDIR"

#======================================================================
# Uncomment following lines to grant DM daemon permission to write 
# in its installation directory tree.

#chmod -R g+w "$ODAOS_DM_HOME"
#chown -vR "$DM_USER" "$ODAOS_DM_HOME"

#======================================================================
# adjust the firewall rules to allow direct access to the DM

# we enable access to port 8082 from anywhere
# and make the iptables chages permanent
#if [ -z "`iptables -nL | grep '^ACCEPT *tcp *-- *0\.0\.0\.0/0 *0\.0\.0\.0/0 *state *NEW *tcp *dpt:8082'`" ]
#then
#    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8082 -j ACCEPT
#    service iptables save
#fi

#======================================================================
# make the donwload manager enabled permanently and start the service

info "Enabling the download manager's service ..."
chkconfig ngeo-dm on
service ngeo-dm start
