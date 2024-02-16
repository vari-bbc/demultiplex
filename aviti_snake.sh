#!/bin/bash
#SBATCH -t 100:00:00
#SBATCH --mem=32G
#SBATCH -c 1
#SBATCH -N 1
#SBATCH -J demultiplex_workflow
#SBATCH -o demultiplex_workflow.o%j
#SBATCH -e demultiplex_workflow.e%j
#SBATCH --mail-type=ALL
##SBATCH SLURM_UMASK=022 

echo "Pipeline started: $(date)"

cd ${SLURM_SUBMIT_DIR} #Change into the run directory

#barcodes_perl=${SLURM_SUBMIT_DIR}/demultiplex/barcodes.pl # Perl script to quantify barcodes
#mergenlanes_script=${SLURM_SUBMIT_DIR}/demultiplex/mergelanes.pl
FC_ID=$(cat RunManifest.csv| grep "RunName" | cut -d ',' -f2)
basecalls_dir=${SLURM_SUBMIT_DIR}/Results/Samples/ 

###========================================== Get run information

rundate="$(cut -d '_' -f1 <<< `basename ${SLURM_SUBMIT_DIR}`)"
machine="$(cut -d '_' -f2 <<< `basename ${SLURM_SUBMIT_DIR}`)"
machine_grep="@${machine}" # used to get overrepresented barcodes in the demultiplexing workflow
runnumber="$(cut -d '_' -f3 <<< `basename ${SLURM_SUBMIT_DIR}`)"
flowcell="$(cut -d '_' -f4 <<< `basename ${SLURM_SUBMIT_DIR}`)"
NOW=`date '+%F_%H:%M:%S'`;
echo "
Information:
	DATETIME: ${NOW}
	RUN DATE: ${rundate}
	MACHINE: ${machine}
	RUN NUMBER: ${runnumber}
	FLOWCELL: ${flowcell}
"

###========================================== Set some paremeters based on the machine

if [ ${machine} == 'AV234602' ]; then # AVITI -f5
	echo "This is an AVITI run."
	project_code_field=5 # 5 if theres a Lane column.
	read2_number_of_cycles=$(cat RunParameters.json | grep -oP '(?<="R2": )\d+') 
	samplesheet_grep=',Lane,'

else
	echo "Exiting:"
	echo "	Did not recognize the sequencing machine (${machine})."
	echo "	(If you are running this is an interactive job: export PWD=\$PWD)"
fi

###========================================== Test if there are project codes

n_project_codes=$(cat RunManifest.csv|grep -A10000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f${project_code_field}|sort|uniq|wc -l)
if [ ! ${n_project_codes} -gt 0 ]; then # if no project codes, fail
	echo "Exiting:"
	echo "	I found zero (${n_project_codes}) project codes! These need to be included!"
	echo "	(If you are running this is an interactive job: export PWD=\$PWD)"
	exit
else
	echo "Information:"
	echo "	Proceeding to demultiplex ${n_project_codes} project codes!"
fi


###========================================== Check the sample sheet

nlanes=$(cat RunManifest.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f4|grep -v '^$'|sort|uniq|wc -l)
n_sample_lane_unique=$(cat RunManifest.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f3-4|grep -v '^$'|grep -v '^,$'|sort|uniq|wc -l)
n_sample_lane=$(cat RunManifest.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f2|grep -v '^$'|sort|wc -l)
n_uniq_sample_names=$(cat RunManifest.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f1|grep -v '^$'|sort|uniq|wc -l) 

if [ ! "${n_sample_lane_unique}" == "${n_sample_lane}" ]; then
	echo "Exiting:"
	echo "	I expected ${n_sample_lane} unique sample/lane combinations (e.g. sample_A_lane_1, sample_A_lane_2), but found ${n_sample_lane_unique} of them."
	exit
fi

###========================================== Demultiplex

echo "Information:"
echo "	Demultiplex ${n_uniq_sample_names} samples on ${nlanes} lanes."
echo "	There are ${n_sample_lane} lane/samples combinations."

# working directory assumed to be directory containing Data/ and demultiplex/ ?????
cd ${SLURM_SUBMIT_DIR}

snakemake_module="bbc2/snakemake/snakemake-7.25.0" 
module load $snakemake_module

# make logs dir if it does not exist already. Without this, logs/ is automatically generate only after the first run of the pipeline
logs_dir="snakemake_job_logs/" # snakemake_runs
[[ -d $logs_dir ]] || mkdir -p $logs_dir

snakefile="demultiplex/bases2fastq_snake/Snakefile"

#snakemake --snakefile $snakefile --dag | dot -Tpng > $logs_dir/dag_${SLURM_JOBID}.png
#snakemake --snakefile $snakefile --filegraph | dot -Tpng > $logs_dir/filegraph_${SLURM_JOBID}.png
#snakemake --snakefile $snakefile --rulegraph | dot -Tpng > $logs_dir/rulegraph_${SLURM_JOBID}.png

echo "Start snakemake workflow. $(date)" >&1
echo "Start snakemake workflow. $(date)" >&2

snakemake \
-p \
--latency-wait 20 \
--snakefile $snakefile \
--use-envmodules \
--jobs 40 \
--cluster "ssh ${SLURM_JOB_USER}@submit001.hpc.vai.org 'module load $snakemake_module; cd $SLURM_SUBMIT_DIR; mkdir -p snakemake_job_logs/{rule}; sbatch \
-p ${SLURM_JOB_PARTITION} \
--export=ALL \
-c {threads} \
--mem={resources.mem_gb}G \
-t 100:00:00 \
-o snakemake_job_logs/{rule}/{resources.log_prefix}.o \
-e snakemake_job_logs/{rule}/{resources.log_prefix}.e'"

echo "snakemake workflow done. $(date)" >&1
echo "snakemake workflow done. $(date)" >&2
