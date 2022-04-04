#! /bin/bash

set -e
set -u
set -o pipefail

if [ $# -ne 1 ]
then
    echo "How to use"
    echo "bash remove_whitespace.sh [SampleSheet.csv]"
    exit 1
fi

if [ -e SampleSheet.csv ]
then
    sed -i -e "s/ //g" $1
    echo "whitespace is removed in $1"
else
    echo "$1 is not found!"
fi
