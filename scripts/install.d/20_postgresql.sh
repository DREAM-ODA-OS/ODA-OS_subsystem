#!/bin/sh
#
# install PostgreSQL and PostGIS installation
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing PosgreSQL RDBM ... "

#======================================================================

# STEP 1: INSTALL RPMS

yum --assumeyes install postgresql postgresql-server postgis python-psycopg2


# STEP 2: CONFIGURE THE STORAGE DIRECTORY 

if [ -n "$ODAOS_PGDATA_DIR" ]
else 
    sudo ex "/etc/rc.d/init.d/postgresql" <<END
g/^PGDATA=/s#\(^PGDATA=\).*#\1$ODAOS_PGDATA_DIR#
g/^PGLOG=/s#\(^PGLOG=\).*#\1$ODAOS_PGDATA_DIR/pgstartup.log#
wq
END 

fi 

# STEP 3: INIT THE DB AND START THE SERVICE  

service postgresql initdb
chkconfig postgresql on
service postgresql start

# STEP 4: SETUP POSTGIS DATABASE TEMPLATE 

if [ -z "`sudo sudo -u postgres psql --list | grep template_postgis`" ] 
then 
    sudo -u postgres createdb template_postgis
    sudo -u postgres createlang plpgsql template_postgis

    PG_SHARE=/usr/share/pgsql

    POSTGIS_SQL="$PG_SHARE/contrib/postgis-64.sql"
    [ -f "$POSTGIS_SQL" ] || POSTGIS_SQL="$PG_SHARE/contrib/postgis.sql"

    sudo -u postgres psql -q -d template_postgis -f "$POSTGIS_SQL"
    sudo -u postgres psql -q -d template_postgis -f "$PG_SHARE/contrib/spatial_ref_sys.sql"
    sudo -u postgres psql -q -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
    sudo -u postgres psql -q -d template_postgis -c "GRANT ALL ON geography_columns TO PUBLIC;"
    sudo -u postgres psql -q -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
fi 
