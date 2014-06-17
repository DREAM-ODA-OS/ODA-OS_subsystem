#!/bin/sh
#
# install Tomcat 6 
#

. `dirname $0`/../lib_logging.sh  

#TOMCAT6_CONF="/etc/sysconfig/tomcat6"
#TOMCAT6_SERVER_XML="/etc/tomcat6/server.xml"
#TOMCAT6_PORT=8080
#TOMCAT6_PORT_APJ=8005
#TOMCAT6_PORT_SD=8009

info "Installing Tomcat6 ... "

# check if tomcat already installed and if so try stop it 
[ -f "/etc/init.d/tomcat6" ] && service tomcat6 stop || : 

# STEP 1: INSTALL RPMS

yum --assumeyes install tomcat6 

# STEP 2: CONFIGURATION 

#ex "$TOMCAT6_CONF" <<END
#/[ 	#]*CONNECTOR_PORT[ 	]*=.*\$/d
#i
#CONNECTOR_PORT="$TOMCAT6_PORT"
#.
#wq
#END
#
#ex "$TOMCAT6_SERVER_XML" <<END
#1,\$s/port="8080"/port="$TOMCAT6_PORT"/g
#1,\$s/port="8005"/port="$TOMCAT6_PORT_APJ"/g
#1,\$s/port="8009"/port="$TOMCAT6_PORT_SD"/g
#wq
#END

# using default setup

# STEP 3: START THE SERVICE  
chkconfig tomcat6 on
service tomcat6 start
