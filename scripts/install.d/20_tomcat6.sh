#!/bin/sh
#
# install Tomcat 6 
#

. `dirname $0`/../lib_logging.sh  

TOMCAT6_CONF="/etc/tomcat6/tomcat6.conf"
TOMCAT6_PORT=8080

info "Installing Tomcat6 ... "

# check if tomcat already installed and if so try stop it 
[ -f "/etc/init.d/tomcat6" ] && service tomcat6 stop || : 

# STEP 1: INSTALL RPMS

yum --assumeyes install tomcat6 

# STEP 2: CONFIGURATION 

ex -V "$TOMCAT6_CONF" <<END
/[ 	#]*CONNECTOR_PORT[ 	]*=.*\$/d
i
CONNECTOR_PORT="$TOMCAT6_PORT"
.
wq
END

# using default setup

# STEP 3: START THE SERVICE  
chkconfig tomcat6 on
service tomcat6 start
