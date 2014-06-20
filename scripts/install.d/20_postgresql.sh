#!/bin/sh
#
# install PostgreSQL and PostGIS
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing PosgreSQL RDBM ... "

#======================================================================

# STEP 0: Shut-down the porgress if already installed and running.

if [ -f "/etc/init.d/postgresql" ]
then 
    service postgresql stop || :
    info "Removing the existing PosgreSQL DB cluster ..."
    # remove existing DB cluster - all data will be lost
    [ ! -d "/var/lib/pgsql/data" ] || rm -fR "/var/lib/pgsql/data" 
    [ ! -d "$ODAOS_PGDATA_DIR" ] || rm -fR "$ODAOS_PGDATA_DIR" 
fi

# STEP 1: INSTALL RPMS

yum --assumeyes install postgresql postgresql-server postgis python-psycopg2

# STEP 2: CONFIGURE THE STORAGE DIRECTORY 

if [ -n "$ODAOS_PGDATA_DIR" ]
then 
    info "Setting the PostgreSQL data location to: $ODAOS_PGDATA_DIR"
    echo "PGDATA=\"$ODAOS_PGDATA_DIR\"" > /etc/sysconfig/pgsql/postgresql
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
