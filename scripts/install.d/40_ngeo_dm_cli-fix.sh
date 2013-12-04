#!/bin/sh
#
# fix the ngEO Downaload Manager's command line utility
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Fixing the ngEO Download Manager's CLI ... "

set -x 
echo 
echo 
echo 
#======================================================================

[ -z "$ODAOS_DM_HOME" ] && error "Missing the required ODAOS_DM_HOME variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"


# get the filename of the CLI JAR 

cd "$ODAOS_DM_HOME"

FNAME="$( ls bin/download-manager-command-line*.jar 2>/dev/null | head -n 1 )" 

[ -z "$FNAME" ] && exit 1 

# fix the script 

DM_CLI="$ODAOS_DM_HOME/start-dm-cli.sh"

info "Fixing the download manager's CLI script: $DM_CLI"

# make the necessary changes
sudo -u "$ODAOSUSER" ex "$DM_CLI" <<END
1,\$s:bin/download-manager-command-line\.jar:$FNAME:g
wq
END

echo 
echo 
echo 
