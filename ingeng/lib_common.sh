#
# common definitions shared by all ingestion engine scripts
#
#

export PATH="/srv/odaos/beam/bin:$PATH"
export PATH="/srv/odaos/tools/metadata:$PATH"
export PATH="/srv/odaos/tools/imgproc:$PATH"
export DJANGO_SETTINGS_MODULE="eoxs.settings"

LOG_FILE="/var/log/odaos/ie_actions.log"

EXENAME=`basename $0`

EOXS_MNG="/usr/bin/python /srv/odaos/eoxs/manage.py"

_hash()
{
# get base64(urlsafe) encoded hash of the standard input
python -c '
from hashlib import md5;
from sys import stdin, stdout;
from base64 import b64encode;
h = md5();
h.update(stdin.read());
s = b64encode(h.digest(),["-","_"]);
stdout.write(s[:22]);
'
}

_remove() { for _file in $* ; do [ -f "$_file" ] && rm -fv "$_file" ; done ; }

_expand()
{
    # USAGE:
    #   _expand <rel-path> [<ref-path>]
    # DESCRIPTION:
    #   Expand full path if <rel-path> with respect
    #   to the (optional) <ref-path> directory.
    #   <rel-path> defaults to the current directory.
    #
    cd "${2:-.}"
    if [ -d "$1" ]
    then
        cd "$1"
        echo "$PWD"
    else
        cd "`dirname "$1"`"
        if [ "$PWD" != "/" ]
        then
            echo "$PWD/`basename "$1"`"
        else
            echo "/`basename "$1"`"
        fi
    fi
}

_detach()
{
    if [ -n "$2" ]
    then
        echo "$1" | sed -e "s#^$2#.#" -e "s#^\./##"
    else
        echo "$1" | sed -e "s#^$PWD#.#" -e "s#^\./##"
    fi
}

_pipe_expand()
{
    while read P
    do
        _expand "$P" "$1"
    done
}

_date() { date -u --iso-8601=seconds | sed -e 's/+0000/Z/' ; }

_print()
{
    MSG="`_date` $EXENAME: $*"
    echo "$MSG"
    { echo "$MSG" >> "$LOG_FILE" ; } 2>/dev/null
}

error() { _print "ERROR: $*" ; }
info()  { _print "INFO: $*" ; }
warn()  { _print "WARNING: $*" ; }

error_pipe() { while read L ; do error "$L" ; done ; }
info_pipe() { while read L ; do info "$L" ; done ; }
warn_pipe() { while read L ; do warn "$L" ; done ; }

# global warp options
WOPT="-multi -wo NUM_THREADS=2 -et 0.25 -r lanczos -wm 256"

# global TIFF options
TOPT="-co TILED=YES -co COMPRESS=DEFLATE -co PREDICTOR=2 -co INTERLEAVE=PIXEL"

# add overview options
ADOOPT="--config COMPRESS_OVERVIEW DEFLATE --config PREDICTOR_OVERVIEW 2 --config INTERLEAVE_OVERVIEW PIXEL -r average"

# preferably use gdaladdo provided by the FWTools
if [ -f "/srv/odaos/fwtools/bin_safe/gdaladdo" ]
then
    GDALADDO="/srv/odaos/fwtools/bin_safe/gdaladdo"
else
    GDALADDO="`which gdaladdo`"
fi

if [ -f "/srv/odaos/fwtools/bin_safe/gdal_translate" ]
then
    GDAL_TRANSLATE="/srv/odaos/fwtools/bin_safe/gdal_translate"
else
    GDAL_TRANSLATE="`which gdal_translate`"
fi

if [ -f "/srv/odaos/fwtools/bin_safe/gdalwarp" ]
then
    GDALWARP="/srv/odaos/fwtools/bin_safe/gdalwarp"
else
    GDALWARP="`which gdalwarp`"
fi
