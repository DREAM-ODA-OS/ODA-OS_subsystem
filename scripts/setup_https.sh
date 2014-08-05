#!/bin/sh -e
#
# HTTPS installation script
#
##################################################################
#source common parts
. `dirname $0`/lib_common.sh
. `dirname $0`/lib_logging.sh
. `dirname $0`/lib_apache.sh

function usage()
{
    echo "ERROR: $EXENAME: Not enough input arguments!" >&2
    echo "USAGE: $EXENAME <sp-cert> <sp-key> [<sp-ca-cert> [<sp-cert-chain>]]" >&2
    echo "OPTIONS:" >&2
    echo "    <sp-cert>  Service Provider (SP) certificate." >&2
    echo "    <sp-key>  SP certificate." >&2
    echo "    <sp-ca-cert>  SP Certificate Authority (CA) root certificate." >&2
    echo "    <sp-cert-chain>  SP CA certification chain." >&2
    echo "NOTE: All inputs must be in the PEM format." >&2
    exit 1
}

function instcrt()
{
    info "... $2 -> $1"
    cat < "$2" > "$1"
}

[ $# -lt 2 ] && { usage ; exit 1 ; }

##################################################################

SP_CERT_FILE="$1"
SP_KEY_FILE="$2"
SP_CERT_CA_FILE="$3"
SP_CERT_CHAIN_FILE="$4"

# locations of the target installed keys and certificates
HTTPD_SP_KEY_FILE="/etc/pki/tls/private/sp-key.pem"           #SP key (apache server)
HTTPD_SP_CERT_FILE="/etc/pki/tls/certs/sp-cert.pem"           #SP cert. (apache server)
HTTPD_SP_CERT_CA_FILE="/etc/pki/tls/certs/sp-ca-cert.pem"        #SP CA cert. (apache server)
HTTPD_SP_CERT_CHAIN_FILE="/etc/pki/tls/certs/sp-ca-chain.pem"      #SP CA cert. chain (apache server)

##################################################################

info "Installing x509 Certificates ..."

# Installing the certificates  certificate. 
instcrt "$HTTPD_SP_KEY_FILE" "$SP_KEY_FILE"
instcrt "$HTTPD_SP_CERT_FILE" "$SP_CERT_FILE"
[ -n "$SP_CERT_CA_FILE" ] && instcrt "$HTTPD_SP_CERT_CA_FILE" "$SP_CERT_CA_FILE"
[ -n "$SP_CERT_CHAIN_FILE" ] && instcrt "$HTTPD_SP_CERT_CHAIN_FILE" "$SP_CERT_CHAIN_FILE"

info "Configuring Apache ..."

CONF=`locate_apache_conf 443`
[ -z "$CONF" ]&&{ error "Failed to find the apache configuration!" ; exit 1 ;}

ex -V "$CONF" <<END
g/^[ 	]*SSLCertificateFile[ 	]\+/d
g/^[ 	]*SSLCertificateKeyFile[ 	]\+/d
/^[ 	]*SSLEngine[ 	]/a
    SSLCertificateFile $HTTPD_SP_CERT_FILE
    SSLCertificateKeyFile $HTTPD_SP_KEY_FILE
.
wq
END

if [ -n "$SP_CERT_CHAIN_FILE" ]
then
    ex -V "$CONF" <<END
g/^[ 	]*SSLCertificateChainFile[ 	]\+/d
/^[ 	]*SSLEngine[ 	]/a
    SSLCertificateChainFile $SP_CERT_CHAIN_FILE 
.
wq
END
fi

if [ -n "$SP_CERT_CA_FILE" ]
then
    ex -V "$CONF" <<END
g/^[ 	]*SSLCACertificateFile[ 	]\+/d
/^[ 	]*SSLEngine[ 	]/a
    SSLCACertificateFile $SP_CERT_CA_FILE
.
wq
END
fi

# reset hostname and restart service 
`dirname $0`/reset_hostname.sh -s $HOSTNAME
