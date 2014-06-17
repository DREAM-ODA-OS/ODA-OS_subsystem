#!/bin/sh
#
# install Tomcat 7
#

. `dirname $0`/../lib_logging.sh  

TOMCAT7_CONF="/etc/sysconfig/tomcat"
TOMCAT7_SERVER_XML="/etc/tomcat/server.xml"
TOMCAT7_PORT=8084
TOMCAT7_PORT_APJ=8205
TOMCAT7_PORT_SD=8209

info "Installing Tomcat7 ... "

# check if tomcat already installed and if so try stop it 
[ -f "/etc/init.d/tomcat" ] && service tomcat stop || : 

# STEP 1: INSTALL RPMS (requires EPEL)

yum --assumeyes install tomcat 

# STEP 2: CONFIGURATION 

ex "$TOMCAT7_CONF" <<END
/[ 	#]*CONNECTOR_PORT[ 	]*=.*\$/d
i
CONNECTOR_PORT="$TOMCAT7_PORT"
.
wq
END

ex -V "$TOMCAT7_SERVER_XML" <<END
1,\$s/port="8080"/port="$TOMCAT7_PORT"/g
1,\$s/port="8005"/port="$TOMCAT7_PORT_APJ"/g
1,\$s/port="8009"/port="$TOMCAT7_PORT_SD"/g
wq
END

# using default setup

# STEP 3: START THE SERVICE  
chkconfig tomcat on
service tomcat start

