#!/bin/bash

set -e
set -u
set -o pipefail

basecalls_dir="Data/Intensities/BaseCalls/"
export basecalls_dir

projects=$(perl -F/,/ -lane 'print qq/$ENV{'basecalls_dir'}$F[9]/ if ($F[9] =~ /^\S/ && $F[9] ne q/Sample_Project/)' SampleSheet.csv  | sort | uniq)
FC_ID=$(cat SampleSheet.csv | grep "Experiment Name" | cut -d ',' -f2)
projects_fc_id=()
for pj in ${projects[@]} ; do
  pj_fc_id="${pj}-${FC_ID}"
  projects_fc_id+=("$pj_fc_id")
done 

target_files="${projects_fc_id[@]} bcl2fastq.done bcl2fastq.log diagnostic_files ${basecalls_dir}Undetermined* ${basecalls_dir}Stats* ${basecalls_dir}Reports* snakemake_job_logs .snakemake missing_fastqs.log low_count_fastqs.log mergelanes.failed"

if ls $target_files >/dev/null 2>&1; then
  echo "Target files found."
else
  echo ""
  echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo "WARNING: Some dmux output files do not exist. Double-check that you are in a dmux directory."
  echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo ""
fi

ls --color $target_files || true

echo ""

while true; do
    read -p "Do you wish to delete the above files?" yn
    case $yn in
        [Yy]* ) echo "Ok, deleting files from previous dmux run."; break;;
        [Nn]* ) echo "Ok exiting script"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

rm -r $target_files
