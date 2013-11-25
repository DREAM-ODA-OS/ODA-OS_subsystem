#!/bin/sh
#
# enable extra RPM repositories 
#

# EPEL: http://fedoraproject.org/wiki/EPEL
rpm -q --quiet epel-release || rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

# ELGIS: http://elgis.argeo.org/
rpm -q --quiet elgis-release || rpm -Uvh http://elgis.argeo.org/repos/6/elgis-release-6-6_0.noarch.rpm

# EOX - EOX RPM repository 
rpm -q --quiet eox-release || rpm -Uvh http://yum.packages.eox.at/el/eox-release-6-2.noarch.rpm


