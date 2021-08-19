#!/bin/bash

set -e
set -u
set -o pipefail

module load bbc/parallel/parallel-20191122

target_files=$(find Data/Intensities/BaseCalls/ -name '*fastq.gz' | sort)
## skip undetermined*.fastq.gz
#target_files=$(find Data/Intensities/BaseCalls/ -name '*fastq.gz' ! -name "Undetermined*.fastq.gz" | sort)

if [ -z "$target_files" ]; then
    echo "No fastq.gz files found."
    exit 1
fi

parallel -k --will-cite -j 8 md5sum ::: $target_files > md5sums.txt
