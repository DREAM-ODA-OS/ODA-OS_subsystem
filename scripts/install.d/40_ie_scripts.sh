#!/bin/sh
#
# install Ingestion Engine actions
#
#======================================================================

. `dirname $0`/../lib_logging.sh  

info "Installing the Ingestion Engine action scripts ... "

#======================================================================

[ -z "$ODAOS_IEAS_HOME" ] && error "Missing the required ODAOS_IEAS_HOME variable!"
[ -z "$ODAOSROOT" ] && error "Missing the required ODAOSROOT variable!"
[ -z "$CONTRIB" ] && error "Missing the required CONTRIB variable!"
[ -z "$INGENG" ] && error "Missing the required INGENG variable!"
[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

USE_SYMLINKS=FALSE
#USE_SYMLINKS=TRUE

#======================================================================

# clean-up previous mess 
[ -d "$ODAOS_IEAS_HOME" -o -h "$ODAOS_IEAS_HOME" ] && rm -fR "$ODAOS_IEAS_HOME"

if [ "TRUE" == "$USE_SYMLINKS" ]
then 
    # symbolic link
    sudo -u "$ODAOSUSER" ln -fs "$INGENG" "$ODAOS_IEAS_HOME"

else 
    # copied files 
    cp -fvR "$INGENG" "$ODAOS_IEAS_HOME"

    # set owner  
    chown -R "$ODAOSUSER:$ODAOSGROUP" "$ODAOS_IEAS_HOME"
fi

#======================================================================

info "Ingestion Engine action scripts installed."
