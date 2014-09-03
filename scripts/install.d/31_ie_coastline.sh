#!/bin/sh
#
# install ODA-OS ingestion engine
#
#======================================================================

. `dirname $0`/../lib_logging.sh

NAME="Coast-Line Dataset"

info "Installing Ingestion Engine $NAME ... "

#======================================================================

[ -z "$ODAOS_IE_HOME" ] && error "Missing the required ODAOS_IE_HOME variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

URL="http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/physical/ne_10m_land.zip"
TARGET="$ODAOS_IE_HOME/ingestion/media/etc/coastline_data"

#======================================================================
# trying to locate the data-file

#
# public domain dataset 
# source: Natural Earth (http://www.naturalearthdata.com/)
#

FILE="`find "$CONTRIB" -name 'ne_10m_land.zip' | sort -r | head -n 1`"

if [ -z "$FILE" ]
then

    info "Downloading from: $URL"

    FILE="$CONTRIB/`basename "$URL"`"

    info "Saving to : $FILE"

    curl -L "$URL" -o "$FILE"

    [ -f "$FILE" ] || error "Failed to download the $NAME!" \
        && info "$NAME downloaded."

else # found - using local copy

    info "Using the existing local copy of the $NAME."

fi

info "$FILE"

#======================================================================

# remove previous data
[ -d "$TARGET" -o -f "$TARGET" ] && rm -fR "$TARGET"

# unpack the data
sudo -u "$ODAOSUSER" mkdir -p "$TARGET"
unzip "$FILE" -d "$TARGET"
chown -R "$ODAOSUSER:$ODAOSGROUP" "$TARGET"

info "$NAME installed to: $TARGET"
