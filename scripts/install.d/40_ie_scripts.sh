#!/bin/sh
#
# install Ingestion Engine actions
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing the Ingestion Engine action scripts ... "

#======================================================================

[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$INGENG" ] && error "Missing the required INGENG variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

USE_SYMLINKS=FALSE
#USE_SYMLINKS=TRUE

IEAS_HOME="$ODAOSROOT/ie_scripts"

#======================================================================

# clean-up previous mess 
[ -d "$IEAS_HOME" -o -h "$IEAS_HOME" ] && rm -fR "$IEAS_HOME"

if [ "TRUE" == "$USE_SYMLINKS" ]
then 
    # symbolic link
    ln -fs "$INGENG" "$IEAS_HOME"

else 
    # copied files 
    cp -fvR "$INGENG" "$IEAS_HOME"

    # set owner  
    chown -R "$ODAOSUSER:$ODAOSGROUP" "$IEAS_HOME"
fi

#======================================================================

info "Ingestion Engine action scripts installed."
