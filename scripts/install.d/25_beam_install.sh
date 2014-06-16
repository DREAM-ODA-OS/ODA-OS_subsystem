#!/bin/sh 
# 
# download and install the BEAM toolbox 
# 
# Copyright (C) 2014 EOX IT Services GmbH

#======================================================================

. `dirname $0`/../lib_logging.sh
#. `dirname $0`/lib_logging.sh

info "Installing BEAM-Toolbox ... "

#======================================================================

[ -z "$ODAOSHOSTNAME" ] && error "Missing the required ODAOSHOSTNAME variable!"
[ -z "$ODAOS_BEAM_HOME" ] && error "Missing the required ODAOS_BEAM_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

BEAM_TMPDIR='/tmp/beam'

# setup automatic cleanup 
on_exit() 
{ 
    [ ! -d "$BEAM_TMPDIR" ] || rm -fR "$BEAM_TMPDIR"
} 
trap on_exit EXIT 

#======================================================================

#BEAM_URL_BC="http://www.brockmann-consult.de/cms/web/beam/dlsurvey?p_p_id=downloadportlet_WAR_beamdownloadportlet10&what=software/beam/4.11/beam_4.11_linux64_installer.sh"
#BEAM_URL_S3="http://org.esa.beam.s3.amazonaws.com/software/beam/4.11/beam_4.11_linux64_installer.sh"
#JAVA_HOME=

#BEAM_URL_BC="http://www.brockmann-consult.de/cms/web/beam/dlsurvey?p_p_id=downloadportlet_WAR_beamdownloadportlet10&what=software/beam/4.11/beam_4.11_unix_installer.sh"
#BEAM_URL_S3="http://org.esa.beam.s3.amazonaws.com/software/beam/4.11/beam_4.11_unix_installer.sh"
#JAVA_HOME="/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64"

BEAM_URL_BC="http://www.brockmann-consult.de/cms/web/beam/dlsurvey?p_p_id=downloadportlet_WAR_beamdownloadportlet10&what=software/beam/5.0.0/beam_5.0_unix_installer.sh&amp;submit=Proceed"
BEAM_URL_S3="http://org.esa.beam.s3.amazonaws.com/software/beam/5.0.0/beam_5.0_unix_installer.sh"
#JAVA_HOME="/srv/odaos/data-quality/q2/local/jdk1.7.0_51"
JAVA_HOME="/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.55.x86_64"

#======================================================================
# Check if there is already a version available in the contrib
# directory. If there is no BEAM installer available donwload it.

BEAM_FILE="`find  "$CONTRIB" -name 'beam_*installer.sh' | sort | tail -n 1 `"

if [ -z "$BEAM_FILE" ]
then
    BEAM_FILE="$CONTRIB/`basename "$BEAM_URL_S3"`"

    info "Downloading from: $BEAM_URL_BC"
    info "Downloading from: $BEAM_URL_S3"
    info "Saving to: $BEAM_FILE"

    curl -s -S -e "$BEAM_URL_BC" "$BEAM_URL_S3" -o "$BEAM_FILE"

    [ -f "$BEAM_FILE" ] || { error "Failed to download the BEAM Toolbox installer." ; exit 1 ; } 

    info "BEAM Toolbox downloaded."

else 
    info "Installer found: $BEAM_FILE"
    info "Using the existing local copy of the BEAM Toolbox installer."
fi

#======================================================================
# run the BEAM installer
BEAM_INSTAL="$BEAM_TMPDIR/`basename "$BEAM_FILE"`"

# cleanup old stuff
[ ! -d "$BEAM_TMPDIR" -a ! -f "$BEAM_TMPDIR" ] || rm -fR "$BEAM_TMPDIR"
[ ! -d "$ODAOS_BEAM_HOME" -a ! -f "$ODAOS_BEAM_HOME" ] || rm -fR "$ODAOS_BEAM_HOME"
mkdir -p "$BEAM_TMPDIR"

info "Fixing the BEAM Toolbox installer ..."
# last line of the leading script 
LNUM=`grep -a -n "^exit" "$BEAM_FILE" | tail -n 1 | cut -f 1 -d ":"`
[ 0 -le "$LNUM" ] || { error "Failed to fix the installer!" ; exit 1 ; }

# extract script
head -n "$LNUM" "$BEAM_FILE" > "$BEAM_INSTAL"

# get total file size 
FSIZE=`stat --format="%s" "$BEAM_FILE"`

# size of the script part 
SSIZE=`stat --format="%s" "$BEAM_INSTAL"`

#size of the binary payload
let BSIZE=FSIZE-SSIZE
[ 0 -le "$BSIZE" ] || { error "Wrong file-size!" ; exit 1 ; }

#----------------------------------------------------
# fix the installation script 

# fix the text part
ex "$BEAM_INSTAL" <<END
2i
INSTALL4J_JAVA_HOME_OVERRIDE="$JAVA_HOME"
.
wq
END

# append the binary payload  
tail -c "$BSIZE" "$BEAM_FILE" >> "$BEAM_INSTAL"

#----------------------------------------------------
# run the installation script 

info "Installing the BEAM Toolbox ..."

sudo -u "$ODAOSUSER" sh "$BEAM_INSTAL" -q -dir "$ODAOS_BEAM_HOME"
