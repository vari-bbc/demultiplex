# demultiplex
Code for demultiplexing NovaSeq and iSeq 


Directions:

Go to the run directory.

```git clone https://github.com/ianbed/demultiplex.git```

OPTIONAL: change the email in demultiplex/bcl2fastq.sh file (#PBS -M your.email@vai.org)

```qsub -q genomics demultiplex/bcl2fastq.sh```

If this doesn't work, check the demultiplex_workflow.[oe]JOB.ID files that are in the run directory.
