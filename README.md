# demultiplex for NovaSeq, NextSeq, and iSeq

Directions:

Go to the run directory.

```git clone https://github.com/ianbed/demultiplex.git```

OPTIONAL: change the email in demultiplex/bcl2fastq.sh file (#PBS -M your.email@vai.org)

```qsub -q genomics demultiplex/bcl2fastq.sh```

If this doesn't work, check the demultiplex_workflow.[oe]JOB.ID files that are in the run directory.

If merging lanes failed (e.g. some samples did not get demultiplexed properly), but you still want to proceed with the rest of the pipeline, then in the run directory type 'touch mergelanes.override' <- this will create a file 'mergelanes.override' that forces the pipeline to continue with the remaining samples.

# demultiplex for sc-atac

Directions:

Go to the run directory.

```git clone https://github.com/ianbed/demultiplex.git```

OPTIONAL: change the email in demultiplex/cellranger_atac_demultiplex.sh file (#PBS -M your.email@vai.org)

```qsub -q genomics demultiplex/cellranger_atac_demultiplex.sh```

If this doesn't work, check the sc-atac-demux.[oe]JOB.ID files that are in the run directory.
