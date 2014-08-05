#!/bin/sh
#
# install Tomcat 7
#

. `dirname $0`/../lib_logging.sh

TOMCAT7_CONF="/etc/sysconfig/tomcat"
TOMCAT7_SERVER_XML="/etc/tomcat/server.xml"
TOMCAT7_PORT=8088
TOMCAT7_PORT_SHD=8085
TOMCAT7_PORT_AJP=8089
TOMCAT7_PORT_SSL=8483

info "Installing Tomcat7 ... "

# check if tomcat already installed and if so try stop it
[ -f "/etc/init.d/tomcat" ] && service tomcat stop || :

# STEP 1: INSTALL RPMS (requires EPEL)

yum --assumeyes install tomcat

# STEP 2: CONFIGURATION

# port setup
ex "$TOMCAT7_CONF" <<END
/[ 	#]*CONNECTOR_PORT[ 	]*=.*\$/d
i
CONNECTOR_PORT="$TOMCAT7_PORT"
.
wq
END

#backup the origianal server.xml
[ -f "${TOMCAT7_SERVER_XML}.bak" ] || cp -fv "$TOMCAT7_SERVER_XML" "${TOMCAT7_SERVER_XML}.bak"

#restore the original server.xml
cp -fv "${TOMCAT7_SERVER_XML}.bak" "$TOMCAT7_SERVER_XML"

# fix the port numbers in server.xml
ex -V "$TOMCAT7_SERVER_XML" <<END
1,\$s/port="8080"/port="$TOMCAT7_PORT"/g
1,\$s/port="8005"/port="$TOMCAT7_PORT_SHD"/g
1,\$s/port="8009"/port="$TOMCAT7_PORT_AJP"/g
1,\$s/port="8443"/port="$TOMCAT7_PORT_SSL"/g
1,\$s/redirectPort="8443"/redirectPort="$TOMCAT7_PORT_SSL"/g
wq
END
# using default setup

# STEP 3: START THE SERVICE
chkconfig tomcat on
service tomcat start

