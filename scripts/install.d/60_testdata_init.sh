#!/bin/sh
#
# initialize the testdata directory on the installed VM 
#
#
#======================================================================

. `dirname $0`/../lib_logging.sh

set -x 
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

cat > "$DOWNLOAD_SH" <<END
#!/bin/sh -e 
#
# automatic data download script
#
cd "\`dirname "\$0"\`"
URL_BASE="http://dream.eox.at/testdata"
if [ -n "\$USER" -a -n "\$PASSWD" ] 
then
    OPT="--no-host-directories --no-parent --cut-dirs=1 -nv"
    for C in ENVISAT SPOT4Take5 GISAT
    do
        echo "Collection: $C"
        [ -d "\$C" -o -f "\$C" ] && rm -fvR "\$C" || true
        wget --user "\$USER" --password "\$PASSWD" \$OPT -r "\$URL_BASE/\$C/"
        [ ! -d "\$C" ] || find "\$C" -name 'index.html*' -exec rm -fv {} \\;
    done 
    echo "DOWNLOAD FINISHED"
else 
    echo "Startig the automated test data download script ..."
    read -p "Enter username: " USER
    read -s -p "Enter password: " PASSWD
    export USER 
    export PASSWD
    echo "Startig background background download process ... "
    echo "To see the progress run: tail -f \$0.log"
    nohup \$0 >\$0.log 2>&1 &
    echo "To stop the process run: kill \$!"
fi 

END
chown -R "$ODAOSUSER:$ODAOSGROUP" "$DOWNLOAD_SH"
chmod +x "$DOWNLOAD_SH"
