#!/bin/sh 
#
# setup EOxServer instance 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Configuring EOxServer ... "

#======================================================================
# NOTE: In ODA-OS, it is not expected to have mutiple instances of the EOxServer

[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSLOGDIR" ] && error "Missing the required ODAOSLOGDIR variable!"
export ODAOSLOGDIR=${ODAOSLOGDIR:-/var/log/odaos}

HOSTNAME="$ODAOSHOSTNAME"
INSTANCE="eoxs00"
INSTROOT="$ODAOSROOT"

SETTINGS="${INSTROOT}/${INSTANCE}/${INSTANCE}/settings.py"
INSTSTAT_URL="/${INSTANCE}_static" # DO NOT USE THE TRAILING SLASH!!!
INSTSTAT_DIR="${INSTROOT}/${INSTANCE}/${INSTANCE}/static"
WSGI="${INSTROOT}/${INSTANCE}/${INSTANCE}/wsgi.py"
MNGCMD="${INSTROOT}/${INSTANCE}/manage.py"

DBENGINE="django.contrib.gis.db.backends.postgis"
DBNAME="eoxs_${INSTANCE}"
DBUSER="eoxs_admin_${INSTANCE}"
DBPASSWD="${INSTANCE}_admin_eoxs"
DBHOST=""
DBPORT=""

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

EOXSLOG="${ODAOSLOGDIR}/eoxserver.log"
EOXSCONF="${INSTROOT}/${INSTANCE}/${INSTANCE}/conf/eoxserver.conf"
EOXSURL="http://${HOSTNAME}/${INSTANCE}/ows"


#-------------------------------------------------------------------------------
# create instance 

info "Creating EOxServer instance '${INSTANCE}' in '$INSTROOT/$INSTANCE' ..."

if [ -d "$INSTROOT/$INSTANCE" ]
then 

    info " The instance seems to already exist. All files will be removed!"
    rm -fvR "$INSTROOT/$INSTANCE"
fi


sudo -u "$ODAOSUSER" mkdir -p "$INSTROOT/$INSTANCE"
sudo -u "$ODAOSUSER" eoxserver-admin.py create_instance "$INSTANCE" "$INSTROOT/$INSTANCE" 

#-------------------------------------------------------------------------------
# create Postgres DB 

info "Creating EOxServer instance's Postgres database '$DBNAME' ..."

# deleting any previously existing database and user 
sudo -u postgres psql -q -c "DROP DATABASE $DBNAME ;" 2>/dev/null \
  && warn " The alredy existing database '$DBNAME' was removed." || /bin/true 

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
1,\$s/\('ENGINE'[	 ]*:[	 ]*\).*\(,\)/\1'$DBENGINE'\2/
1,\$s/\('NAME'[	 ]*:[	 ]*\).*\(,\)/\1'$DBNAME'\2/
1,\$s/\('USER'[	 ]*:[	 ]*\).*\(,\)/\1'$DBUSER'\2/
1,\$s/\('PASSWORD'[	 ]*:[	 ]*\).*\(,\)/\1'$DBPASSWD'\2/
1,\$s/\('HOST'[	 ]*:[	 ]*\).*\(,\)/#\1'$DBHOST'\2/
1,\$s/\('PORT'[	 ]*:[	 ]*\).*\(,\)/#\1'$DBPORT'\2/
1,\$s:\(STATIC_URL[	 ]*=[	 ]*\).*:\1'$INSTSTAT_URL/':
wq
END
#ALLOWED_HOSTS = []

#-------------------------------------------------------------------------------
# Integration with the Apache web server  

info "Mapping EOxServer instance '${INSTANCE}' to URL path '${INSTANCE}' ..."

# locate proper configuration file (see also apache configuration)

CONFS="/etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf"
CONF=

for F in $CONFS 
do
    if [ 0 -lt `grep -c '^[ 	]*<VirtualHost[ 	]*\*:80>' $F` ] 
    then 
        CONF=$F
        break 
    fi
done

[ -z "CONFS" ] && error "Cannot find the Apache VirtualHost configuration file."

# insert the configuration to the virtual host 

#/^[ 	]*<VirtualHost[ 	]*\*:80>/a
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
    </Directory>

    # static content 
    Alias $INSTSTAT_URL "$INSTSTAT_DIR"
    <Directory "$INSTSTAT_DIR">
            Options -MultiViews +FollowSymLinks
            AllowOverride None
            Order Allow,Deny
            Allow from all
    </Directory>

    # EOXS00_END - EOxServer instance - Do not edit or remove this line! 
.
wq
END

#-------------------------------------------------------------------------------
# EOxServer configuration 

# set the service url and log-file 
#/^[	 ]*logging_filename[	 ]*=/s;\(^[	 ]*logging_filename[	 ]*=\).*;\1${EOXSLOG};
sudo -u "$ODAOSUSER" ex "$EOXSCONF" <<END
/^[	 ]*http_service_url[	 ]*=/s;\(^[	 ]*http_service_url[	 ]*=\).*;\1${EOXSURL};
g/^#.*supported_crs/,/^$/ s/^#//
wq
END

# set the log-file 
sudo -u "$ODAOSUSER" ex "$SETTINGS" <<END
g/^LOGGING[	 ]*=/,/^}/s;^\([	 ]*'filename'[	 ]*:\).*;\1 '${EOXSLOG}',;
wq
END
#wq

# touch the logfifile and set the right permissions 
touch ${EOXSLOG}
chown -v "$ODAOSUSER:$ODAOSGROUP" ${EOXSLOG}
chmod -v 0664 ${EOXSLOG}  

#-------------------------------------------------------------------------------
# Django syncdb (without interactive prompts) 

info "Initializing EOxServer instance '${INSTANCE}' ..."

# collect static files 
sudo -u "$ODAOSUSER" python "$MNGCMD" collectstatic -l --noinput

# setup new database 
sudo -u "$ODAOSUSER" python "$MNGCMD" syncdb --noinput 

#-------------------------------------------------------------------------------
# restart apache to force the changes to take effect 

service httpd restart
