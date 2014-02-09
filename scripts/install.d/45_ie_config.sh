#!/bin/sh
#
# configure ODA-OS ingestion engine 
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Configuring Ingestion Engine ... "

#======================================================================
# NOTE: In ODA-OS, it is not expected to have mutiple instances of the EOxServer

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

set -x 

# ingestion_config.json 
sudo -u "$ODAOSUSER" ex "$INGESTION_CONFIG" <<END
1,\$s:\("DownloadManagerDir"[	 ]*\:[	 ]*"\).*\("[	 ]*,\):\1$ODAOS_DM_HOME\2:
wq
END

# settings.py 
sudo -u "$ODAOSUSER" ex "$SETTINGS" <<END
1,\$s:^\(LOGGING_DIR[	 ]*=[	 ]*\).*$:\1"$ODAOSLOGDIR":
wq
END
SETTINGS="${INSTROOT}/${INSTANCE}/settings.py"

#-------------------------------------------------------------------------------
# Django syncdb (without interactive prompts) 

info "Initializing EOxServer instance '${INSTANCE}' ..."

# collect static files 
sudo -u "$ODAOSUSER" python "$MNGCMD" collectstatic -l --noinput

# setup new database 
sudo -u "$ODAOSUSER" python "$MNGCMD" syncdb --noinput 
