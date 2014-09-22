#!/bin/sh
#
# setup EOxServer instance
#
#======================================================================

. `dirname $0`/../lib_logging.sh
. `dirname $0`/../lib_apache.sh

info "Configuring EOxServer ... "

#======================================================================
# NOTE: In ODA-OS, it is not expected to have mutiple instances of the EOxServer

[ -z "$ODAOS_IEAS_HOME" ] && error "Missing the required ODAOS_IEAS_HOME variable!"
[ -z "$ODAOS_BEAM_HOME" ] && error "Missing the required ODAOS_BEAM_HOME variable!"
[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"

HOSTNAME="$ODAOSHOSTNAME"
INSTANCE="eoxs"
INSTROOT="$ODAOSROOT"

SETTINGS="${INSTROOT}/${INSTANCE}/${INSTANCE}/settings.py"
INSTSTAT_URL="/${INSTANCE}_static" # DO NOT USE THE TRAILING SLASH!!!
INSTSTAT_DIR="${INSTROOT}/${INSTANCE}/${INSTANCE}/static"
WSGI="${INSTROOT}/${INSTANCE}/${INSTANCE}/wsgi.py"
MNGCMD="${INSTROOT}/${INSTANCE}/manage.py"

DBENGINE="django.contrib.gis.db.backends.postgis"
DBNAME="eoxs_${INSTANCE}"
DBUSER="eoxs_admin_${INSTANCE}"
DBPASSWD="${INSTANCE}_admin_eoxs_`head -c 24 < /dev/urandom | base64 | tr '/' '_'`"
DBHOST=""
DBPORT=""

PG_HBA="${ODAOS_PGDATA_DIR:-/var/lib/pgsql/data}/pg_hba.conf"

EOXSLOG="${ODAOSLOGDIR}/eoxserver.log"
EOXSCONF="${INSTROOT}/${INSTANCE}/${INSTANCE}/conf/eoxserver.conf"
EOXSURL="http://${HOSTNAME}/${INSTANCE}/ows?"
EOXSMAXSIZE="20480"
EOXSMAXPAGE="200"

#-------------------------------------------------------------------------------
# create instance

info "Creating EOxServer instance '${INSTANCE}' in '$INSTROOT/$INSTANCE' ..."

if [ -d "$INSTROOT/$INSTANCE" ]
then

    info " The instance seems to already exist. All files will be removed!"
    rm -fvR "$INSTROOT/$INSTANCE"
fi

# check availability of the EOxServer
#HINT: Does python complain that the apparently installed EOxServer
#      package is not available? First check that the 'eoxserver' tree is
#      readable by anyone. (E.g. in case of read protected home directory when
#      the development setup is used.)
sudo -u "$ODAOSUSER" python -c 'import eoxserver' || {
    error "EOxServer does not seem to be installed!"
    exit 1
}

sudo -u "$ODAOSUSER" mkdir -p "$INSTROOT/$INSTANCE"
sudo -u "$ODAOSUSER" eoxserver-admin.py create_instance "$INSTANCE" "$INSTROOT/$INSTANCE"

#-------------------------------------------------------------------------------
# create Postgres DB

info "Creating EOxServer instance's Postgres database '$DBNAME' ..."

# deleting any previously existing database
sudo -u postgres psql -q -c "DROP DATABASE $DBNAME ;" 2>/dev/null \
  && warn " The already existing database '$DBNAME' was removed." || /bin/true

# deleting any previously existing user
TMP=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DBUSER' ;"`
if [ 1 == "$TMP" ]
then
    sudo -u postgres psql -q -c "DROP USER $DBUSER ;"
    warn " The alredy existing database user '$DBUSER' was removed"
fi

# create new users
sudo -u postgres psql -q -c "CREATE USER $DBUSER WITH ENCRYPTED PASSWORD '$DBPASSWD' NOSUPERUSER NOCREATEDB NOCREATEROLE ;"
sudo -u postgres psql -q -c "CREATE DATABASE $DBNAME WITH OWNER $DBUSER TEMPLATE template_postgis ENCODING 'UTF-8' ;"

# prepend to the beginning of the acess list
{ sudo -u postgres ex "$PG_HBA" || /bin/true ; } <<END
g/# EOxServer instance:.*\/$INSTANCE/d
g/^[	 ]*local[	 ]*$DBNAME/d
/#[	 ]*TYPE[	 ]*DATABASE[	 ]*USER[	 ]*CIDR-ADDRESS[	 ]*METHOD/a
# EOxServer instance: $INSTROOT/$INSTANCE
local	$DBNAME	$DBUSER	md5
local	$DBNAME	all	reject
.
wq
END

service postgresql restart

#-------------------------------------------------------------------------------
# setup Django DB backend

sudo -u "$ODAOSUSER" ex "$SETTINGS" <<END
1,\$s/\('ENGINE'[	 ]*:[	 ]*\).*\(,\)/\1'$DBENGINE',/
1,\$s/\('NAME'[	 ]*:[	 ]*\).*\(,\)/\1'$DBNAME',/
1,\$s/\('USER'[	 ]*:[	 ]*\).*\(,\)/\1'$DBUSER',/
1,\$s/\('PASSWORD'[	 ]*:[	 ]*\).*\(,\)/\1'$DBPASSWD',/
1,\$s/\('HOST'[	 ]*:[	 ]*\).*\(,\)/#\1'$DBHOST',/
1,\$s/\('PORT'[	 ]*:[	 ]*\).*\(,\)/#\1'$DBPORT',/
1,\$s:\(STATIC_URL[	 ]*=[	 ]*\).*:\1'$INSTSTAT_URL/':
wq
END
#ALLOWED_HOSTS = []

#-------------------------------------------------------------------------------
# Integration with the Apache web server

info "Mapping EOxServer instance '${INSTANCE}' to URL path '${INSTANCE}' ..."

# locate proper configuration file (see also apache configuration)
{
    locate_apache_conf 80
    locate_apache_conf 443
} | while read CONF
do
    { ex "$CONF" || /bin/true ; } <<END
/EOXS00_BEGIN/,/EOXS00_END/de
/^[ 	]*<\/VirtualHost>/i
    # EOXS00_BEGIN - EOxServer instance - Do not edit or remove this line!

    # EOxServer instance configured by the automatic installation script

    # WSGI service endpoint
    Alias /$INSTANCE "${INSTROOT}/${INSTANCE}/${INSTANCE}/wsgi.py"
    <Directory "${INSTROOT}/${INSTANCE}/${INSTANCE}">
            Options +ExecCGI -MultiViews +FollowSymLinks
            AddHandler wsgi-script .py
            WSGIProcessGroup eoxs_ows
            AllowOverride None
            Order Allow,Deny
            Allow from all
            Header set Access-Control-Allow-Origin "*"
            Header set Access-Control-Allow-Headers Content-Type
            Header set Access-Control-Allow-Methods "POST, GET"
    </Directory>

    # static content
    Alias $INSTSTAT_URL "$INSTSTAT_DIR"
    <Directory "$INSTSTAT_DIR">
            Options -MultiViews +FollowSymLinks
            AllowOverride None
            Order Allow,Deny
            Allow from all
            Header set Access-Control-Allow-Origin "*"
    </Directory>

    # EOXS00_END - EOxServer instance - Do not edit or remove this line!
.
wq
END
done

#-------------------------------------------------------------------------------
# EOxServer configuration

# set the service url and log-file
#/^[	 ]*logging_filename[	 ]*=/s;\(^[	 ]*logging_filename[	 ]*=\).*;\1${EOXSLOG};
sudo -u "$ODAOSUSER" ex "$EOXSCONF" <<END
/^[	 ]*http_service_url[	 ]*=/s;\(^[	 ]*http_service_url[	 ]*=\).*;\1${EOXSURL};
g/^#.*supported_crs/,/^$/d
/\[services\.ows\.wms\]/a

supported_crs=4326,3857,900913, # WGS84, WGS84 Pseudo-Mercator, and GoogleEarth spherical mercator
        3035, #ETRS89
        2154, # RGF93 / Lambert-93
        32601,32602,32603,32604,32605,32606,32607,32608,32609,32610, # WGS84 UTM  1N-10N
        32611,32612,32613,32614,32615,32616,32617,32618,32619,32620, # WGS84 UTM 11N-20N
        32621,32622,32623,32624,32625,32626,32627,32628,32629,32630, # WGS84 UTM 21N-30N
        32631,32632,32633,32634,32635,32636,32637,32638,32639,32640, # WGS84 UTM 31N-40N
        32641,32642,32643,32644,32645,32646,32647,32648,32649,32650, # WGS84 UTM 41N-50N
        32651,32652,32653,32654,32655,32656,32657,32658,32659,32660, # WGS84 UTM 51N-60N
        32701,32702,32703,32704,32705,32706,32707,32708,32709,32710, # WGS84 UTM  1S-10S
        32711,32712,32713,32714,32715,32716,32717,32718,32719,32720, # WGS84 UTM 11S-20S
        32721,32722,32723,32724,32725,32726,32727,32728,32729,32730, # WGS84 UTM 21S-30S
        32731,32732,32733,32734,32735,32736,32737,32738,32739,32740, # WGS84 UTM 31S-40S
        32741,32742,32743,32744,32745,32746,32747,32748,32749,32750, # WGS84 UTM 41S-50S
        32751,32752,32753,32754,32755,32756,32757,32758,32759,32760  # WGS84 UTM 51S-60S
        #32661,32761, # WGS84 UPS-N and UPS-S
.
/\[services\.ows\.wcs\]/a

supported_crs=4326,3857,900913, # WGS84, WGS84 Pseudo-Mercator, and GoogleEarth spherical mercator
        3035, #ETRS89
        2154, # RGF93 / Lambert-93
        32601,32602,32603,32604,32605,32606,32607,32608,32609,32610, # WGS84 UTM  1N-10N
        32611,32612,32613,32614,32615,32616,32617,32618,32619,32620, # WGS84 UTM 11N-20N
        32621,32622,32623,32624,32625,32626,32627,32628,32629,32630, # WGS84 UTM 21N-30N
        32631,32632,32633,32634,32635,32636,32637,32638,32639,32640, # WGS84 UTM 31N-40N
        32641,32642,32643,32644,32645,32646,32647,32648,32649,32650, # WGS84 UTM 41N-50N
        32651,32652,32653,32654,32655,32656,32657,32658,32659,32660, # WGS84 UTM 51N-60N
        32701,32702,32703,32704,32705,32706,32707,32708,32709,32710, # WGS84 UTM  1S-10S
        32711,32712,32713,32714,32715,32716,32717,32718,32719,32720, # WGS84 UTM 11S-20S
        32721,32722,32723,32724,32725,32726,32727,32728,32729,32730, # WGS84 UTM 21S-30S
        32731,32732,32733,32734,32735,32736,32737,32738,32739,32740, # WGS84 UTM 31S-40S
        32741,32742,32743,32744,32745,32746,32747,32748,32749,32750, # WGS84 UTM 41S-50S
        32751,32752,32753,32754,32755,32756,32757,32758,32759,32760  # WGS84 UTM 51S-60S
        #32661,32761, # WGS84 UPS-N and UPS-S
.
wq
END

#set the limits
sudo -u "$ODAOSUSER" ex "$EOXSCONF" <<END
g/^[ 	#]*maxsize[ 	]/d
g/^[ 	#]*path_beam[ 	]/d
g/^[ 	#]*beam_options[ 	]/d
/\[services\.ows\.wcs\]/a
# maximum allowed output coverage size 
# (nether width nor height can exceed this limit)
maxsize = $EOXSMAXSIZE
.
/\[core\.system]/a
path_beam=$ODAOS_BEAM_HOME
beam_options=-c 256M
.
/^[	 ]*source_to_native_format_map[	 ]*=/s#\(^[	 ]*source_to_native_format_map[	 ]*=\).*#\1application/x-esa-envisat,application/x-netcdf#
/^[	 ]*paging_count_default[	 ]*=/s/\(^[	 ]*paging_count_default[	 ]*=\).*/\1${EOXSMAXPAGE}/

wq
END

# set the allowed hosts
sudo -u "$ODAOSUSER" ex "$SETTINGS" <<END
1,\$s/\(^ALLOWED_HOSTS[	 ]*=[	 ]*\).*/\1['$HOSTNAME','127.0.0.1','::1']/
wq
END

# set-up logging
sudo -u "$ODAOSUSER" ex "$SETTINGS" <<END
g/^DEBUG[	 ]*=/s#\(^DEBUG[	 ]*=[	 ]*\).*#\1False#
g/^LOGGING[	 ]*=/,/^}/d
a
LOGGING = {
    'version': 1,
    'disable_existing_loggers': True,
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse'
        }
    },
    'formatters': {
        'simple': {
            'format': '[%(module)s] %(levelname)s: %(message)s'
        },
        'verbose': {
            'format': '[%(asctime)s][%(module)s] %(levelname)s: %(message)s'
        }
    },
    'handlers': {
        'eoxserver_file': {
            'level': 'DEBUG',
            'class': 'logging.handlers.WatchedFileHandler',
            'filename': '${EOXSLOG}',
            'formatter': 'verbose',
            'filters': [],
        },
        'stderr_stream': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
            'filters': [],
        },
    },
    'loggers': {
        'eoxserver': {
            'handlers': ['eoxserver_file'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        '': {
            'handlers': ['eoxserver_file'],
            'level': 'INFO' if DEBUG else 'WARNING',
            'propagate': False,
        },
    }
}
.
wq
END
#wq

# touch the logfifile and set the right permissions
[ -f "$EOXSLOG" ] && rm -fv "$EOXSLOG"
touch "$EOXSLOG"
chown -v "$ODAOSUSER:$ODAOSGROUP" "$EOXSLOG"
chmod -v 0664 "$EOXSLOG"

#-------------------------------------------------------------------------------
# Django syncdb (without interactive prompts)

info "Initializing EOxServer instance '${INSTANCE}' ..."

# collect static files
sudo -u "$ODAOSUSER" python "$MNGCMD" collectstatic -l --noinput

# setup new database
sudo -u "$ODAOSUSER" python "$MNGCMD" syncdb --noinput

# load range types (when available)
INITIAL_RANGETYPES="$ODAOS_IEAS_HOME/range_types.json"
[ -f "$INITIAL_RANGETYPES" ] && sudo -u "$ODAOSUSER" python "$MNGCMD" eoxs_rangetype_load < "$INITIAL_RANGETYPES"

#-------------------------------------------------------------------------------
# restart apache to force the changes to take effect

service httpd restart
