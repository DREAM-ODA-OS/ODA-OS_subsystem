#
# common definitions shared by all ingestion engine scripts 
#
#

export PATH="/srv/odaos/tools/metadata:$PATH"
export PATH="/srv/odaos/tools/imgproc:$PATH"
export DJANGO_SETTINGS_MODULE="eoxs.settings"

LOG_FILE="/var/log/odaos/ie_actions.log"

EXENAME=`basename $0`

EOXS_MNG="/usr/bin/python /srv/odaos/eoxs/manage.py"

_date() { date -u --iso-8601=seconds | sed -e 's/+0000/Z/' ; } 

_print() 
{
    MSG="`_date` $EXENAME: $*"
    echo "$MSG" 
    echo "$MSG" >> "$LOG_FILE"
}

error() { _print "ERROR: $*" ; }
info()  { _print "INFO: $*" ; }
warn()  { _print "WARNING: $*" ; }
