#!/bin/sh
#
# initialize the testdata directory on the installed VM
#
#
#======================================================================

. `dirname $0`/../lib_logging.sh

TD_DIR="/srv/eodata/testdata"
DOWNLOAD_SH="$TD_DIR/download_test_data.sh"
info "Initializing the test data directory $TD_DIR"

[ -z "$ODAOSUSER" ] && error "Missing the required ODAOSUSER variable!"
[ -z "$ODAOSGROUP" ] && error "Missing the required ODAOSGROUP variable!"

if [ -f "$TD_DIR" ]
then
    rm -fR "$TD_DIR"
fi

mkdir -p "$TD_DIR"
chown -R "$ODAOSUSER:$ODAOSGROUP" "$TD_DIR"

cat > "$DOWNLOAD_SH" <<END_END
#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) 2014 EOX IT Services GmbH
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

BASE_NAME="\`basename "\$0"\`"
BASE_DIR="\$(cd \`dirname "\$0"\` ; pwd ; )"
URL_BASE="http://dream.eox.at/testdata"
LOG_FILE="\$BASE_DIR/\$BASE_NAME.log"
WGETRC="\$HOME/.wgetrc"

_date() { date -u --iso-8601=seconds | sed -e 's/+0000//' ; }

_print()
{
    MSG="\`_date\` \$EXENAME: \$*"
    echo "\$MSG"
    { echo "\$MSG" >> "\$LOG_FILE" ; } 2>/dev/null
}

error() { _print "ERROR: \$*" ; }
info()  { _print "INFO: \$*" ; }
warn()  { _print "WARNING: \$*" ; }

error_pipe() { while read L ; do error "\$L" ; done ; }
info_pipe() { while read L ; do info "\$L" ; done ; }
warn_pipe() { while read L ; do warn "\$L" ; done ; }

_wget_file()
{
    [ -n "\$1" ] || { error "_wget_file: No filename specified!" ; return 1 ; }
    FNAME="\$BASE_DIR/\$1"
    [ -f "\$FNAME" -o -d "\$FNAME" ] && rm -fvR "\$FNAME" 2>&1 | info_pipe
    mkdir -p "\`dirname "\$FNAME"\`" 2>&1 | error_pipe
    wget -nv "\$URL_BASE/\$1" -O "\$FNAME" 2>&1 | info_pipe
    RT="\${PIPESTATUS[0]}"
    [ "\$RT" -ne 0 ] && error "Download failed!" || info "File downloaded."
    return "\$RT"
}

_md5sum_check()
{
    [ -n "\$1" ] || { error "_md5sum_check: No checksum specified!" ; return 1 ; }
    [ -n "\$2" ] || { error "_md5sum_check: No filename specified!" ; return 1 ; }
    FNAME="\$BASE_DIR/\$2"
    [ -f "\$FNAME" ] || { error "_md5sum_check: File does not exist! \$FNAME" ; return 1 ; }
    CHSUM="\`md5sum "\$FNAME" | cut -f 1 -d ' '\`"
    if [ "\$1" != "\$CHSUM" ]
    then
        info "Invalid checksum!"
        return 1
    else
        info "Checksum is OK."
    fi
}

_set_wgetrc()
{
    touch "\$WGETRC"
    chmod 0600 "\$WGETRC"
    cat > "\$WGETRC" <<END
user=\$USER
password=\$PASSWD
END
}

_unset_wgetrc()
{
    [ -f "\$WGETRC" ] && rm -fR "\$WGETRC" | error_pipe
}

cd "\`dirname "\$0"\`"
if [ -n "\$USER" -a -n "\$PASSWD" ]
then
    trap "error 'Download killed!' ; _unset_wgetrc" SIGINT SIGTERM
    _set_wgetrc 2>&1 | error_pipe
    if [ -z "\$1" ]
    then
        info "Downloading the index file ..."
        INDEX="index.md5"
        _wget_file "\$INDEX" || exit 1
        INDEX="\$BASE_DIR/\$INDEX"
    else
        info "Using the user provided index file ..."
        INDEX="\$1"
    fi
    [ -f "\$INDEX" ] || { error "Invalid index file: \$INDEX" ; exit 1 ; }
    info "Index file: \$INDEX"
    NFILE="\`wc -l <"\$INDEX"\`"
    IFILE="0"
    cat "\$INDEX" | while read L
    do
        let "IFILE=IFILE+1"
        F="\`echo "\$L" | sed -e 's/^[0-9a-f]\{32,32\}  //'\`"
        H="\`echo "\$L" | cut -f 1 -d ' '\`"
        info "Downloading: \$IFILE/\$NFILE \$F"
        if [ -f "\$F" ]
        then
            info "Verifying the MD5 checksum of the existing file ..."
            _md5sum_check "\$H" "\$F" && { info "Download skipped." ; continue ; }
            warn "The file needs to be downloaded again! \$F"
        fi
        _wget_file "\$F" || continue
        info "Verifying the MD5 checksum of the downloaded file ..."
        _md5sum_check "\$H" "\$F" || { error "Download failed! \$F" ; continue ; }
        info "File downloaded successfully."
    done
    info "DOWNLOAD FINISHED"
else
    info "Starting the automated test data download script ..."
    read -p "Enter username: " USER
    read -s -p "Enter password: " PASSWD
    export USER
    export PASSWD
    info "Starting background background download process ... "
    info "To see the progress run: tail -f \$LOG_FILE"
    nohup "\$BASE_DIR/\$BASE_NAME" "\$INDEX" >/dev/null 2>&1 &
    PID="\$!"
    info "The background download may take hours to finish."
    info "It is safe to logout and check the progress later."
    info "The PID of the background process is: \$PID"
    info "To kill the process use: kill -- -\`ps -o pgid --no-headers --pid "\$PID" | sed 's/\s//g'\`"
fi
END_END
chown -R "$ODAOSUSER:$ODAOSGROUP" "$DOWNLOAD_SH"
chmod +x "$DOWNLOAD_SH"
