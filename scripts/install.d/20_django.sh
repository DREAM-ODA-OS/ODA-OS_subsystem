#!/bin/sh 
#
# install Django (required by the Ingestion Engine)
#
#======================================================================

# STEP 1:  INSTALL RPMS

yum --assumeyes install Django14 python-django-dajax


# STEP 2:  PIP INSTALLERS 

# install django-jquery 
pip install django-jquery
