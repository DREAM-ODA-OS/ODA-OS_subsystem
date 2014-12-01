#!/bin/sh
#-------------------------------------------------------------------------------
#
# Project: DREAM - Task 5 - ODA-OS 
# Purpose: ODA-OS installation script - common shared defaults 
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2013 EOX IT Services GmbH
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

# version 
export ODAOSVERSION=0.4.3

# public hostname (or IP number) under which the ODA-OS shall be accessable 
# NOTE: Critical parameter! Be sure you set to proper value.
export ODAOSHOSTNAME=${ODAOSHOSTNAME:-$HOSTNAME}

# root directory of the ODA-OS subsystem - by default set to '/srv/odaos'
export ODAOSROOT=${ODAOSROOT:-/srv/odaos}

# directory where the log files shall be places - by default set to '/var/log/odaos'
export ODAOSLOGDIR=${ODAOSLOGDIR:-/var/log/odaos}

# directory where the PosgreSQL DB stores the files
export ODAOS_PGDATA_DIR=${ODAOS_PGDATA_DIR:-/srv/pgdata} 

# directory of the long-term data storage - by default set to '/srv/eodata'
export ODAOSDATADIR=${ODAOSDATADIR:-/srv/eodata}

# directory of the short-term data storage - by default set to '/srv/eodata/tmp'
# NOTE: the purpose of this directory is not to replace the /tmp but 
#       rather to be used as a subsytem's temporary workspace
export ODAOSTMPDIR=${ODAOSTMPDIR:-/srv/eodata/tmp}

# names of the ODA-OS user and group - by default set to 'odaos:apache'
export ODAOSGROUP=${ODAOSGROUP:-apache}
export ODAOSUSER=${ODAOSUSER:-odaos}

# location of the ngEO downaload manager home directory
export ODAOS_DM_HOME=${ODAOS_DM_HOME:-$ODAOSROOT/ngeo-dm}

# location of the Ingestion Engine home directory
export ODAOS_IE_HOME=${ODAOS_IE_HOME:-$ODAOSROOT/ingeng}

# location of the Ingestion Engine actions scripts home directory
export ODAOS_IEAS_HOME=${ODAOS_IEAS_HOME:-$ODAOSROOT/ie-scripts}

# location of the ODA Client home directory 
export ODAOS_ODAC_HOME=${ODAOS_ODAC_HOME:-$ODAOSROOT/oda-client}

# location of the DQ subsystem  
export ODAOS_DQ_HOME=${ODAOS_DQ_HOME:-$ODAOSROOT/data-quality}

# location of the DQ Client
export ODAOS_DQC_HOME=${ODAOS_DQS_HOME:-$ODAOS_DQ_HOME/q1}

# location of the BEAM installation
export ODAOS_BEAM_HOME=${ODAOS_BEAM_HOME:-$ODAOSROOT/beam}

# location of the FWTools installation
export ODAOS_FWTOOLS_HOME=${ODAOS_FWTOOLS_HOME:-$ODAOSROOT/fwtools}
