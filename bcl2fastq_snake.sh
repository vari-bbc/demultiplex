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

messages=/secondary/projects/genomicscore/tools/boilerplate_demux/novaseq/messages/ # Larry's message files here
FC_ID=$(cat SampleSheet.csv | grep "Experiment Name" | cut -d ',' -f2)

barcodes_perl=${SLURM_SUBMIT_DIR}/demultiplex/barcodes.pl # Perl script to quantify barcodes
mergenlanes_script=${SLURM_SUBMIT_DIR}/demultiplex/mergelanes.pl
barcodes_perl=/secondary/projects/genomicscore/tools/boilerplate_demux/Barcodes.pl # Perl script to quantify barcodes
basecalls_dir=${SLURM_SUBMIT_DIR}/Data/Intensities/BaseCalls/
cd ${SLURM_SUBMIT_DIR} #Change into the run directory
#======================================================================= Get the run information
rundate="$(cut -d '_' -f1 <<< `basename ${SLURM_SUBMIT_DIR}` )"
machine="$(cut -d '_' -f2 <<< `basename ${SLURM_SUBMIT_DIR}` )"
machine_grep="@${machine}" # used to get overrepresented barcodes in the demultiplexing workflow
runnumber="$(cut -d '_' -f3 <<< `basename ${SLURM_SUBMIT_DIR}` )"
flowcell="$(cut -d '_' -f4 <<< `basename ${SLURM_SUBMIT_DIR}` )"
NOW=`date '+%F_%H:%M:%S'`;
echo "
Information:
	DATETIME: ${NOW}
	RUN DATE: ${rundate}
	MACHINE: ${machine}
	RUN NUMBER: ${runnumber}
	FLOWCELL: ${flowcell}
"
#~ exit
#======================================================================= # Set some parameters based on the machine
if [ ${machine} == 'MN01106' ]; then # MINISEQ -f12
	echo "This is an MINISEQ run."
	project_code_field=10 # 12 for miniseq
	read2_number_of_cycles=$(cat RunParameters.xml|grep '<ReadType>'|sed -e 's/<ReadType>//'|sed -e 's/<\/ReadType>//'|sed -e 's/ //g') 
	samplesheet_grep='^Lane'
elif [ ${machine} == 'A00426' ]; then # NOVASEQ -f10
	echo "This is a NOVASEQ run."
	project_code_field=10 # 10 for novaseq
	read2_number_of_cycles=$(cat RunParameters.xml|grep '<Read2NumberOfCycles>'|sed -e 's/<Read2NumberOfCycles>//'|sed -e 's/<\/Read2NumberOfCycles>//'|sed -e 's/ //g') 
	samplesheet_grep='^Lane'
elif [ ${machine} == 'NS500653' ]; then # NEXTSEQ -f9
	echo "This is a NEXTSEQ run."
	project_code_field=9 # 9 for nextseq
	read2_number_of_cycles=$(cat RunParameters.xml|grep '<Read2>'|sed -e 's/<Read2>//'|sed -e 's/<\/Read2>//'|sed -e 's/ //g') 
	samplesheet_grep='^Sample_ID'
else
	echo "Exiting:"
	echo "	Did not recognize the sequencing machine (${machine})."
	echo "	(If you are running this is an interactive job: export PWD=\$PWD)"
fi
#======================================================================= Test if there are project codes
n_project_codes=$(cat SampleSheet.csv|grep -A10000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq|wc -l)
if [ ! ${n_project_codes} -gt 0 ]; then # if no project codes, fail
	echo "Exiting:"
	echo "	I found zero (${n_project_codes}) project codes! These need to be included!"
	echo "	(If you are running this is an interactive job: export PWD=\$PWD)"
	exit
else
	echo "Information:"
	echo "	Proceeding to demultiplex ${n_project_codes} project codes!"
fi
#======================================================================= Check the sample sheet
nlanes=$(cat SampleSheet.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f1|grep -v '^$'|sort|uniq|wc -l)
n_sample_lane_unique=$(cat SampleSheet.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f1-2|grep -v '^$'|grep -v '^,$'|sort|uniq|wc -l)
n_sample_lane=$(cat SampleSheet.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f2|grep -v '^$'|sort|wc -l)
n_uniq_sample_names=$(cat SampleSheet.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f2|grep -v '^$'|sort|uniq|wc -l) 
if [ ${machine} == 'NS500653' ]; then # NEXTSEQ -f9
	nlanes=4
fi
if [ ! "${n_sample_lane_unique}" == "${n_sample_lane}" ]; then
	echo "Exiting:"
	echo "	I expected ${n_sample_lane} unique sample/lane combinations (e.g. sample_A_lane_1, sample_A_lane_2), but found ${n_sample_lane_unique} of them."
	exit
fi
#======================================================================= Demultiplex
echo "Information:"
echo "	Demultiplex ${n_uniq_sample_names} samples on ${nlanes} lanes."
echo "	There are ${n_sample_lane} lane/samples combinations (ignore if nextseq)."

#~ exit

# working directory assumed to be directory containing Data/ and demultiplex/ 
cd ${SLURM_SUBMIT_DIR}

snakemake_module="bbc2/snakemake/snakemake-7.25.0" 
module load $snakemake_module

# make logs dir if it does not exist already. Without this, logs/ is automatically generate only after the first run of the pipeline
logs_dir="snakemake_job_logs/" # snakemake_runs
[[ -d $logs_dir ]] || mkdir -p $logs_dir

snakefile="demultiplex/bcl2fastq_snake/Snakefile"

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

cd $PWD
diagf=${SLURM_SUBMIT_DIR}/diagnostic_files/
mkdir -p ${diagf}
echo "
Information:
	Done with FastQC/MultiQC!
	Generating diagnostic files in ${diagf}
" 

#======================================================================= Generate diagnostic files
#### Undetermined Index Quantification
index_summary=${diagf}IndexSummary.txt
echo "Information:"
if [ ! -f ${index_summary} ]; then
	echo "	Creating an index summary file \"${index_summary}\""
	/secondary/projects/genomicscore/tools/interop-build/src/apps/index-summary . > ${index_summary} # create index Summary for all lanes
else
	echo "	Index summary file \"${index_summary}\" exists"
fi

undetermined=${basecalls_dir}Undetermined_L000_R1_001.fastq.gz # check for the L000 file, these need to be in the BaseCall dir


echo "Information:"
if [ ! -f $undetermined ]; then
	echo "	Was going to quantify indexes in $undetermined, but I didn't find this file in ${basecalls_dir}"
else
	for lane in `ls ${basecalls_dir} | grep Undetermined|grep -v L000|cut -d '_' -f3|sort|uniq`; do # get uniq lanes, undetermined gets a file foreach lane
		
		lane_grep="Lane ${lane/L00/}"
		echo "	Quantifying indexes in ${lane_grep}"
		PF_READS=$(cat ${index_summary}|grep -A2 "$lane_grep"|tail -n+3|sed -e 's/^ //'|sed 's/\s\s*/ /g'|cut -d ' ' -f2)
		echo "		Found $PF_READS paired fragments for $lane_grep"
		file=${basecalls_dir}Undetermined_S0_${lane}_R1_001.fastq.gz

		if [ ! -f ${diagf}Barcodes_${lane}.txt ]; then
			echo "		Quantifying barcodes in $lane_grep (${lane}) in ${file}"
			echo "Count	Barcode" > ${diagf}Barcodes_${lane}.txt
			echo "zcat $file | grep '^${machine_grep}'|cut -d ' ' -f2|cut -d ':' -f4|sort|uniq -c|sed -e 's/^ *//'|tr ' ' '\t' >> ${diagf}Barcodes_${lane}.txt"|sh # this contains all of the barcodes & their counts for $lane
			#~ zcat $file | grep '^${machine_grep}'|cut -d ' ' -f2|cut -d ':' -f4|sort|uniq -c|sed -e 's/^ *//'|tr ' ' '\t' > ${diagf}Barcodes_${lane}.txt # this contains all of the barcodes & their counts for $lane
		else
			echo "		${diagf}Barcodes_${lane}.txt exists"
		fi

		signif_fraction=0.0005
		barcodes_signif_outfile=${diagf}Barcodes_fraction_greater_than_${signif_fraction}_${lane}.txt
		if [ ! -f ${barcodes_signif_outfile} ]; then
			echo "		Quantifying barcodes that represent a significant fraction of the total reads (fraction greater than ${signif_fraction})"
			# now invoke the perl script to get all barcodes that constitute >2% of the total Undetermined
			perl ${barcodes_perl} ${signif_fraction} $PF_READS ${diagf}Barcodes_${lane}.txt ${read2_number_of_cycles} > ${barcodes_signif_outfile}
		else
			echo "		${diagf}BarcodesSignifFraction_${lane}.txt exists!"
		fi
	done
fi


### PercentOccupiedByLane
pof=${diagf}PercentOccupiedByLane.csv # percent occupied file
plot_by_lane=/secondary/projects/genomicscore/tools/interop-build/src/apps/plot_by_lane

if [ ! -f $pof ]; then
	echo "	Generating percent occupied by lane file: ${pof}"
	echo "Lane,Min_PercentOccupied,P25_PercentOccupied,Median_PercentOccupied,P75_PercentOccupied,Max_PercentOccupied" > ${pof}
	${plot_by_lane} . --metric-name=PercentOccupied |grep -e '^[[:digit:]]'  >> ${pof}
else
	echo "	Percent occupied by lane file (${pof}) exists"
fi


### Link in Multiqc files to diagnostics folder
for p in `cat ${SLURM_SUBMIT_DIR}/SampleSheet.csv|grep -A1000 ${samplesheet_grep}|grep -v ${samplesheet_grep}|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq`; do
	mqc=${basecalls_dir}${p}-${FC_ID}/multiqc_report.html
	if [ -f $mqc ]; then
		ln -sf ${mqc} ${diagf}${p}-${FC_ID}_multiqc_report.html
	else
		echo "Did not find multiqc file for project \"${p}-${FC_ID}\" ($mqc)"
	fi
done



echo "Information:"
echo "	I'm done demultiplexing...goodbye..." 
echo "Pipeline run to completion: $(date)"
