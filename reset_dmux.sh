#!/bin/bash

set -e
set -u
set -o pipefail

basecalls_dir="Data/Intensities/BaseCalls/"
export basecalls_dir

projects=$(perl -F/,/ -lane 'print qq/$ENV{'basecalls_dir'}$F[9]/ if ($F[9] =~ /^\S/ && $F[9] ne q/Sample_Project/)' SampleSheet.csv  | sort | uniq)

target_files="$projects bcl2fastq.done bcl2fastq.log diagnostic_files ${basecalls_dir}Undetermined* ${basecalls_dir}Stats* ${basecalls_dir}Reports*"

#ls $target_files

if ls $target_files >/dev/null 2>&1; then
  ls --color $target_files
else
  echo "ERROR: Some dmux output files do not exist. In case you are trying to delete something unintentionally, this script will exit now."
  ls $target_files
  exit 1 # should error out from above line but putting this here for extra security
fi

while true; do
    read -p "Do you wish to delete the above files?" yn
    case $yn in
        [Yy]* ) echo "Ok, deleting files from previous dmux run."; break;;
        [Nn]* ) echo "Ok exiting script"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

rm -r $target_files
