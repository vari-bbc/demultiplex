#!/bin/bash

set -e
set -u
set -o pipefail

module load bbc/parallel/parallel-20191122

parallel -k --will-cite -j 16 md5sum ::: $(find Data/Intensities/BaseCalls/ -name '*fastq.gz' | sort) > md5sums.txt
