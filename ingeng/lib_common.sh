#
# common definitions shared by all ingestion engine scripts 
#
#

export PATH="/srv/odaos/tools/metadata:$PATH"
export PATH="/srv/odaos/tools/imgproc:$PATH"
export DJANGO_SETTINGS_MODULE="eoxs.settings"

EXENAME=`basename $0`

EOXS_MNG="/usr/bin/python /srv/odaos/eoxs/manage.py"

error() { echo "ERROR: $EXENAME: $1" ; }
info()  { echo "INFO: $EXENAME: $1" ; }
warn()  { echo "WARNING: $EXENAME: $1" ; }
