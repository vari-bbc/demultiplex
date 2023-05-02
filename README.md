# demultiplex workflow

Table of Contents
=================

   * [demultiplex for NovaSeq, NextSeq, and iSeq](#demultiplex-for-novaseq-nextseq-and-iseq)
      * [New workflow](#new-workflow)
      * [Legacy workflow (non-parallelized fastqc and fastq_screen)](#legacy-workflow-non-parallelized-fastqc-and-fastq_screen)
      * [Miscellaneous](#miscellaneous)
         * [Running preseq](#running-preseq)
         * [Dealing with samples with no/few reads](#dealing-with-samples-with-nofew-reads)
         * [Kill all demultiplex jobs](#kill-all-demultiplex-jobs)
         * ['Reset' the run directory](#reset-the-run-directory)
         * [Calculate md5sums for all fastq files in the run directory](#calculate-md5sums-for-all-fastq-files-in-the-run-directory)
   * [demultiplex for sc-atac](#demultiplex-for-sc-atac)

# demultiplex for NovaSeq, NextSeq, and iSeq

## New workflow

Directions:

Go to the run directory.

```git clone https://github.com/vari-bbc/demultiplex.git```

OPTIONAL: Add the directive for email notifications in demultiplex/bcl2fastq_snake.sh file (#PBS -M your.email@vai.org)

```sbatch -p genomics demultiplex/bcl2fastq_snake.sh```


## Legacy workflow (non-parallelized fastqc and fastq_screen)

Directions:

Go to the run directory.

```git clone https://github.com/vari-bbc/demultiplex.git```

OPTIONAL: change the email in demultiplex/bcl2fastq.sh file (#PBS -M your.email@vai.org)

```sbatch -p genomics demultiplex/bcl2fastq.sh```

If this doesn't work, check the demultiplex_workflow.[oe]JOB.ID files that are in the run directory.

If merging lanes failed (e.g. some samples did not get demultiplexed properly), but you still want to proceed with the rest of the pipeline, then in the run directory type 'touch mergelanes.override' <- this will create a file 'mergelanes.override' that forces the pipeline to continue with the remaining samples. You can specify this before the run if you want.


## Miscellaneous

### Running preseq

Enable or disable running Preseq, by changing 'run' to True or False in `bcl2fastq_snake/config.yaml`. You must also indicate whether the data is 'DNA' or 'RNA' sequencing and which reference to align to. Look inside `bcl2fastq_snake/config.yaml` for more details.

### Dealing with samples with no/few reads

Empty placeholder fastq files and output files from other QC tools will be created for samples with no reads. Fastq files that end up with 0 reads will be listed in a file named `missing_fastqs.log` immediately after `bcl2fastq` is run and will also be listed in the multiQC reports.

Low count files, which are fastq files with read count less than the minimum value set in `demultiplex/bcl2fastq_snake/config.yaml`, are listed in `low_count_fastqs.log` only after all FastQC jobs are finished because it uses the FastQC output to determine the counts. These low count files are also listed in the multiQC reports.

If a samplesheet error is noticed after examining `missing_fastqs.log` or `low_count_fastqs.log`, you may want to kill all the demultiplex PBS jobs immediately instead of waiting for the jobs to finish. After that, you can 'reset' the demultiplexing directory and restart the pipeline by running `qsub -q genomics demultiplex/bcl2fastq_snake.sh` (if using the Snakemake pipeline) again. See sections below on [killing PBS jobs](#kill-all-demultiplex-jobs) and how to ['reset' the directory](#reset-the-run-directory).

### Kill all demultiplex jobs

If you want to stop the demultiplexing pipeline, you need to kill all the running jobs.

First, run the following to check that only demultiplexing jobs are matched.

```qstat -u user.name | grep -P '\ssnakejob\.|demultiplex'```

Then, run the following to kill those jobs.

```qstat -u user.name | grep -P '\ssnakejob\.|demultiplex' | grep -Po '^\d+' | xargs qdel```

### 'Reset' the run directory

In case you need to rerun a pipeline, you may want to get rid of files created by the previous run.

```./demultiplex/reset_dmux.sh```

### Calculate md5sums for all fastq files in the run directory

This can take some time to run and uses up to 8 cores, so you should run this as an interactive PBS job, requesting 8 cores.

```./demultiplex/fastq_md5sums.sh```


# demultiplex for sc-atac

Directions:

Go to the run directory.

```git clone https://github.com/ianbed/demultiplex.git```

OPTIONAL: change the email in demultiplex/cellranger_atac_demultiplex.sh file (#PBS -M your.email@vai.org)

```qsub -q genomics demultiplex/cellranger_atac_demultiplex.sh```

If this doesn't work, check the sc-atac-demux.[oe]JOB.ID files that are in the run directory.
