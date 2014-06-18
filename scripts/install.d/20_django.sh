#!/bin/sh
#
# install Django (required by the Ingestion Engine)
#
#======================================================================

. `dirname $0`/../lib_logging.sh

info "Installing Django ..."

# STEP 1:  INSTALL RPMS
yum --assumeyes install Django14 python-django-dajax

# STEP 2:  PIP INSTALLERS
pip install django-jquery
