#!/bin/bash

set -e
set -u
set -o pipefail

basecalls_dir="Data/Intensities/BaseCalls/"
export basecalls_dir

projects=$(perl -F/,/ -lane 'print qq/$ENV{'basecalls_dir'}$F[9]/ if ($F[9] =~ /^\S/ && $F[9] ne q/Sample_Project/)' SampleSheet.csv  | sort | uniq)

target_files="$projects bcl2fastq.done bcl2fastq.log diagnostic_files ${basecalls_dir}Undetermined* ${basecalls_dir}Stats* ${basecalls_dir}Reports*"

ls $target_files

while true; do
    read -p "Do you wish to delete the above files?" yn
    case $yn in
        [Yy]* ) echo "Ok, deleting files from previous dmux run."; break;;
        [Nn]* ) echo "Ok exiting script"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

rm -r $target_files
