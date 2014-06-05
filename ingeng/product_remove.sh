#!/usr/bin/env sh
# 
#   Remove product from the ODA server.
#
# USAGE: 
#   product_remove.sh <nc_id> [-catreg=<script>]
#
# DESCRIPTION: 
#
#  DREAM Delete script template.
#  This script is invoked by the Ingestion Engine
#  when a scenario is deleted.
#  It is expected that the script will de-register
#  products associated with the scenario, and delete the
#  corresponding physical files on the disc (filesystem).
#
# catreg is used to request de-registration of products
#        from the local metadata catalogue. The script
#        is the name of the script to be executed.
#        If absent no deregistration  should be done.
#
#  The script should exit with a 0 status to indicate
# success; a non-zero status indicates failure, and will
# prevent the scenario to be deleted from the Ingestion
# Engine's list of scenarios.
#

. "`dirname $0`/lib_common.sh"

info "Product removal started ..."
info "   ARGUMENTS: $* "

error "NOT IMPLEMENTED!" ; exit 1 


#script_name="Default delete script"
#
#echo $script_name "started."
#
#if [[ $# < 1 ]]
#then
#    echo "Not enough args," $script_name "exiting with status 1."
#    exit 1
#fi
#
#echo arg1: $1
#
#if [[ $2 == -catreg=* ]]
#then
#    echo $2
#    echo $script_name ": Catalogue de-registration requested."
#    catderegscript=${2:8}
#    echo "cat deregistration script: " $catderegscript
#    if [[ -f $catderegscript ]] ; then
#        echo "Ing. script: Running catalogue de-registration script."
#        $catderegscript
#        cat_reg_status=$?
#        echo 'cat. de-reg. script exited with ' $cat_reg_status
#        if [ $cat_reg_status != 0 ] ; then ex_status=$cat_reg_status; fi
#    else
#        echo $script_name ": did not find an executable cat. de-reg. script ."
#        ex_status=3
#    fi
#fi
#
#echo "---"
#echo " WARNING: Product removal action not yet implemented!"
#echo "---"
#
#echo $script_name "finishing with status 0."
#exit 0
