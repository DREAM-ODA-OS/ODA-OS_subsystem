#!/usr/bin/env bash
echo "Update MetaData script started on" $(date)
echo args: $*

if [[ $# < 3 ]]
then
    echo "Not enough args, exiting with status 5."
    exit 5
fi

if [[ $1 == '-add' ]]
then
    echo "action=add" 
elif [[ $1 == '-replace' ]]
then
    echo "action=replace" 
else
    echo '***bad action: ' $1
    echo "exiting with status 1"
    exit 1
fi

if [[ ! -f $3 ]]
then
    echo "No file: " $3
    echo echo "exiting with status 3"
    exit 3
fi

echo "test uqmd finishing with status 0."
exit 0
