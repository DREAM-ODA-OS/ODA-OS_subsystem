#!/bin/sh
#-------------------------------------------------------------------------------
#
# Project: DREAM - Task 5 - ODA-OS 
# Purpose: ODA-OS installation script 
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2013 EOX IT Services GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies of this Software or works derived from this Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

#source common parts
. `dirname $0`/lib_common.sh  
. `dirname $0`/lib_logging.sh  

#export location of the contrib directory 

export CONTRIB="$(cd "$(dirname "$0")/../contrib"; pwd )"

#-------------------------------------------------------------------------------
# check whether the user and group exists 
# if not create them 

_mkdir()
{ # <owner>[:<group>] <permissions> <dirname> <label>
    if [ ! -d "$3" ] 
    then 
        info "Creating $4: $3"
        mkdir -p "$3"
    fi 
    chown -v "$1" "$3"
    chmod -v "$2" "$3"
} 

id -g "$ODAOSGROUP" >/dev/null 2>&1 || \
{ 
    info "Creatting system group: $ODAOSGROUP"
    groupadd -r "$ODAOSGROUP"
}


id -u "$ODAOSUSER" >/dev/null 2>&1 || \
{ 
    info "Creatting system user: $ODAOSUSER"
    useradd -r -m -g "$ODAOSGROUP" -d "$ODAOSROOT" -c "ODA-OS system user" "$ODAOSUSER"
} 

# just in case the ODA-OS directories do not exists create them
# and set the right permissions 

_mkdir "$ODAOSUSER:$ODAOSGROUP" 0755 "$ODAOSROOT" "subsytem's root directory" 
_mkdir "$ODAOSUSER:$ODAOSGROUP" 0775 "$ODAOSLOGDIR" "subsytem's logging directory" 
_mkdir "$ODAOSUSER:$ODAOSGROUP" 0775 "$ODAOSDATADIR" "subsytem's long-term data storage directory"
_mkdir "$ODAOSUSER:$ODAOSGROUP" 0775 "$ODAOSTMPDIR" "subsytem's short-term data stoarage directory"

#-------------------------------------------------------------------------------
# execute specific installation scripts 

if [ $# -eq 1 ] 
then 
    # execute selected scripts only 
    SCRIPTS=$*
else 
    # execute all scripts 
    SCRIPTS="`dirname $0`/install.d/"*.sh
fi 

for SCRIPT in $SCRIPTS
do
    info "Executing installation script: $SCRIPT" 
    sh -e $SCRIPT
    [ 0 -ne "$?" ] && warn "Installation script ended with an error: $SCRIPT"
done

info "Installation has been completed." 
