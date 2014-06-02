#!/bin/sh
#
# configure rasdaman/petasscope/WCPS
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Configuring Rasdaman ... "

#======================================================================
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"

dbuser_delete()
{
    TMP=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$1' ;"`
    if [ 1 == "$TMP" ]
    then
        sudo -u postgres psql -q -c "DROP USER $1 ;"
        warn " The alredy existing database user '$1' was removed"
    fi
}


PG_HBA="${ODAOS_PGDATA_DIR:-/var/lib/pgsql/data}/pg_hba.conf"

#INSTANCE="ras00"
DBHOST=""
DBPORT=""
DBRASDAMAN="RASBASE"
DBPETASCOP="petascopedb"
RASADMIN="rasadmin"
PSDBUSER="petascope"
PSDBPASSWD="petascope_`head -c 24 < /dev/urandom | base64 | tr '/' '_'`"
PSPROP="/etc/rasdaman/petascope.properties"
RASCONNECT_DIR="/srv/odaos/.rasdaman"
RASCONNECT_FILE="$RASCONNECT_DIR/rasconnect"

# stop the services if they are runngin
service rasdaman stop || :
service tomcat6 stop || :

#----------------------------------------------------------------------
info "Creating Rasdaman/Petascope PostgreSQL database ..."

# re-set the petascope properties
# needed to allow petascopeinitdb access the actual DB 
ex $PSPROP <<END 
g/metadata_user/s/^[ 	]*\(metadata_user\)[ 	]*=.*\$/\1=tomcat/
g/metadata_pass/s/^[ 	]*\(metadata_pass\)[ 	]*=.*\$/\1=/
wq
END

# reset the access control
{ sudo -u postgres ex "$PG_HBA" || /bin/true ; } <<END
g/# rasdaman instance:.*$INSTANCE/d
g/^[	 ]*local[	 ]*$DBRASDAMAN/d
g/^[	 ]*local[	 ]*$DBPETASCOP/d
g/^[	 ]*host[	 ]*$DBRASDAMAN/d
g/^[	 ]*host[	 ]*$DBPETASCOP/d
.
wq
END

service postgresql restart

# deleting any previously existing database
service rasdaman dropdb || :
service rasdaman droppetascopedb || :

# deleting any previously existing user
dbuser_delete "$PSDBUSER"

#----------------------------------------------------------------------

# create the new databases 
service rasdaman initdb
service rasdaman initpetascopedb

# create petascope DB new user and grant it priviledges
# TODO: get rid of the superuser property 
sudo -u postgres psql -q -c "CREATE USER $PSDBUSER WITH ENCRYPTED PASSWORD '$PSDBPASSWD' LOGIN SUPERUSER NOCREATEDB NOCREATEROLE ;"
sudo -u postgres psql -q -c "GRANT ALL PRIVILEGES ON DATABASE $DBPETASCOP TO $PSDBUSER"

# setup the access control
{ sudo -u postgres ex "$PG_HBA" || /bin/true ; } <<END
g/# rasdaman instance:.*$INSTANCE/d
g/^[	 ]*local[	 ]*$DBRASDAMAN/d
g/^[	 ]*local[	 ]*$DBPETASCOP/d
g/^[	 ]*host[	 ]*$DBRASDAMAN/d
g/^[	 ]*host[	 ]*$DBPETASCOP/d
/#[	 ]*TYPE[	 ]*DATABASE[	 ]*USER[	 ]*CIDR-ADDRESS[	 ]*METHOD/a
# rasdaman instance: $INSTANCE
local	$DBRASDAMAN	rasdaman    ident
local	$DBRASDAMAN	all	reject
host	$DBRASDAMAN	all	127.0.0.1/32	reject
host	$DBRASDAMAN	all	::1/128	reject
local	$DBPETASCOP	$PSDBUSER	md5
host	$DBPETASCOP	$PSDBUSER	127.0.0.1/32	md5
host	$DBPETASCOP	$PSDBUSER	::1/128	md5
local	$DBPETASCOP	all	reject
host	$DBPETASCOP	all	127.0.0.1/32	reject
host	$DBPETASCOP	all	::1/128	reject
.
wq
END

service postgresql restart

# set petascope properties
ex $PSPROP <<END 
g/metadata_user/s/^[ 	]*\(metadata_user\)[ 	]*=.*\$/\1=$PSDBUSER/
g/metadata_pass/s/^[ 	]*\(metadata_pass\)[ 	]*=.*\$/\1=$PSDBPASSWD/
g/rasdaman_user/s/^[ 	]*\(rasdaman_user\)[ 	]*=.*\$/\1=$RASADMIN/
g/rasdaman_pass/s/^[ 	]*\(rasdaman_pass\)[ 	]*=.*\$/\1=$RASADMIN/
g/rasdaman_admin_user/s/^[ 	]*\(rasdaman_admin_user\)[ 	]*=.*\$/\1=$RASADMIN/
g/rasdaman_admin_pass/s/^[ 	]*\(rasdaman_admin_pass\)[ 	]*=.*\$/\1=$RASADMIN/
wq
END

#----------------------------------------------------------------------
info "Starting Rasdaman/Petascope services ..."

service rasdaman start
service tomcat6 start


#----------------------------------------------------------------------
info "Setting Petascope behind the Apache reverse proxy ..."

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

# delete any previous configuration and write a new one
{ ex "$CONF" || /bin/true ; } <<END
/RAS00_BEGIN/,/RAS00_END/de
/^[ 	]*<\/VirtualHost>/i
    # RAS00_BEGIN - Rasdaman/Petascope - Do not edit or remove this line!

    # reverse proxy to the Rasdaman/Petascope
    ProxyPreserveHost On
    ProxyPass        /petascope http://127.0.0.1:8080/petascope
    ProxyPassReverse /petascope http://127.0.0.1:8080/petascope

    # RAS00_END - Rasdaman/Petascope - Do not edit or remove this line!
.
wq
END

# restart apache to force the changes to take effect
service httpd restart

#----------------------------------------------------------------------
# needed by rasimport - to be removed 

[ -d "$RASCONNECT_DIR" ] || sudo -u "$ODAOSUSER" mkdir -p "$RASCONNECT_DIR"
[ -f "$RASCONNECT_FILE" ] && rm -fv "$RASCONNECT_FILE"

if [ ! -f "$RASCONNECT_FILE" ] 
then 
    sudo -u "$ODAOSUSER" touch "$RASCONNECT_FILE"
    sudo -u "$ODAOSUSER" chmod 0700 "$RASCONNECT_DIR"
    sudo -u "$ODAOSUSER" chmod 0600 "$RASCONNECT_FILE"
    sudo -u "$ODAOSUSER" cat >>"$RASCONNECT_FILE" <<END 
host=localhost
rasport=7001
pgport=5432
rasdbname=RASBASE
petadbname=petascopedb
rasuser=$RASADMIN
raspassword=$RASADMIN
petauser=$PSDBUSER
petapassword=$PSDBPASSWD
rasloginuser=$RASADMIN
rasloginpassword=$RASADMIN
END
fi 
#----------------------------------------------------------------------
