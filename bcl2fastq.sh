#PBS -l walltime=100:00:00
#PBS -l mem=90gb
#PBS -l nodes=1:ppn=8
#PBS -M your.email@vai.org
#PBS -m abe
#PBS -N demultiplex_workflow

messages=/secondary/projects/genomicscore/tools/boilerplate_demux/novaseq/messages/ # Larry's message files here
mergenlanes_script=/secondary/projects/genomicscore/tools/mergelanes/mergeNovaseqLanes2.pl
barcodes_perl=${PBS_O_WORKDIR}/demultiplex/barcodes.pl # Perl script to quantify barcodes
mergenlanes_script=${PBS_O_WORKDIR}/demultiplex/mergelanes.pl
barcodes_perl=/secondary/projects/genomicscore/tools/boilerplate_demux/Barcodes.pl # Perl script to quantify barcodes
basecalls_dir=${PBS_O_WORKDIR}/Data/Intensities/BaseCalls/
cd ${PBS_O_WORKDIR} #Change into the run directory
rundate="$(cut -d '_' -f1 <<< `basename ${PBS_O_WORKDIR}` )"
machine="$(cut -d '_' -f2 <<< `basename ${PBS_O_WORKDIR}` )"
machine_grep="@${machine}"
runnumber="$(cut -d '_' -f3 <<< `basename ${PBS_O_WORKDIR}` )"
flowcell="$(cut -d '_' -f4 <<< `basename ${PBS_O_WORKDIR}` )"
NOW=`date '+%F_%H:%M:%S'`;
echo "
INFORMATION:
	DATETIME: ${NOW}
	RUN DATE: ${rundate}
	MACHINE: ${machine}
	RUN NUMBER: ${runnumber}
	FLOWCELL: ${flowcell}
" 
nlanes=$(cat SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f1|grep -v '^$'|sort|uniq|wc -l)
n_uniq_sample_lane=$(cat SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f1-2|grep -v '^$'|sort|uniq|wc -l)
n_sample_lane=$(cat SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f2|grep -v '^$'|sort|wc -l)
n_uniq_sample_names=$(cat SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f2|grep -v '^$'|sort|uniq|wc -l) 
if [ ${machine} == 'FS10000742' ]; then # iSeq -f12
	echo "INFORMATION:"
	echo "	iSeq run"
	project_code_field=12
	read2_number_of_cycles=$(cat RunParameters.xml|grep '<ReadType>'|sed -e 's/<ReadType>//'|sed -e 's/<\/ReadType>//'|sed -e 's/ //g') # terrible but effective :)
else # novaseq -f10
	echo "INFORMATION:"
	echo "	NovaSeq run"
	project_code_field=10
	read2_number_of_cycles=$(cat RunParameters.xml|grep '<Read2NumberOfCycles>'|sed -e 's/<Read2NumberOfCycles>//'|sed -e 's/<\/Read2NumberOfCycles>//'|sed -e 's/ //g') # terrible but effective :)
fi

n_project_codes=$(cat SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq|wc -l)

if [ ! ${n_project_codes} -gt 0 ]; then # if no project codes, fail
	echo "INFORMATION:"
	echo "	I found ${n_project_codes} project codes!"
	echo "	(Ian, if you are running this is interactive: export PBS_O_WORKDIR=\$PWD)"
	exit
else
	echo "INFORMATION:"
	echo "	Proceeding with ${n_project_codes} project codes!"
fi

#======================================================================= demultiplex & mergelanes
if [ ! "${n_uniq_sample_lane}" == "${n_sample_lane}" ]; then # if sample sheet error
	echo "INFORMATION:"
	echo "	I expected ${n_sample_lane} unique sample/lane combinations, but found ${n_uniq_sample_lane} of them?"
	exit
else
	echo "INFORMATION:"
	echo "	I am proceeding to demultiplex ${n_uniq_sample_names} unique samples."
	echo "	These are on ${nlanes} lanes."
	echo "	There are ${n_sample_lane} lane/samples combinations."
	demux_flag=${PBS_O_WORKDIR}/bcl2fastq.done
	if [ ! -f ${demux_flag} ]; then
		echo "INFORMATION:"
		echo "	Demultiplexing with bcl2fastq..." 
		/secondary/projects/genomicscore/tools/bcl2fastq/default/bin/bcl2fastq &> bcl2fastq.log #Launch standard bcl2fastq
	else # or not if it's alredy done
		echo "INFORMATION:"
		echo "	Found ${demux_flag}. I'm not demultiplexing with bcl2fastq."
	fi

	cd ${basecalls_dir} #Change into the BaseCalls directory

	#Merge NOVASEQ lanes
	echo "INFORMATION:"
	echo "	Merging ${nlanes} lanes into L000 files (I am in directory $PWD)"
	mergelanes_cmd="${mergenlanes_script} ${PBS_O_WORKDIR}/SampleSheet.csv ${read2_number_of_cycles} ${machine} ${PBS_O_WORKDIR}/"
	perl ${mergelanes_cmd}
	
	mergelanes_override=${PBS_O_WORKDIR}/mergelanes.override # if you still want to proceed (e.g. some samples not supposed to be in the samplesheet.csv)
	mergelanes_flag=${PBS_O_WORKDIR}/mergelanes.failed
	if [ -e ${mergelanes_flag} ]; then
		if [ ! -e ${mergelanes_override} ]; then
			echo "INFORMATION:"
			echo "	Failing because the mergelanes failed"
			echo "INFORMATION:"
			echo "	To diagnose the error, run \"${mergelanes_cmd}\""
			echo "	Once the error is fixed remove ${mergelanes_flag} and resubmit the demultiplexing job." 
			#~ cat ${messages}encouragement.message
			exit
		else
			echo "INFORMATION:"
			echo "	Mergelanes FAILED, but I received an override"
		fi
	else
		echo "INFORMATION:"
		echo "	Mergelanes PASS! (did not find ${mergelanes_flag}"
	fi
fi

cd $PBS_O_WORKDIR

echo "INFORMATION:"
echo "	Demultiplexing and L000 file generation is now done!"

#======================================================================= fastqc / multiqc
##### FASTQC on samples
echo "INFORMATION:"
echo "	FastQC..."
for p in `cat ${PBS_O_WORKDIR}/SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq`; do
	#Launch FastQC
	number_of_L000_files=$(ls ${basecalls_dir}${p}|grep _L000_.*.fastq.gz|wc -l) # fastq files only
	mkdir -p ${basecalls_dir}${p}/FastQC
	if [ ${number_of_L000_files} -gt 0 ]; then
		echo "		Launching FastQC on merged L000 files for project ${p}"
		for s in `ls ${basecalls_dir}${p}/|grep _L000_.*.fastq.gz|grep -v Undetermined`; do 
			f=$(sed -e 's/.fastq.gz/_fastqc.html/' <<< $s)
			if [ ! -f ${basecalls_dir}${p}/FastQC/${f} ]; then
				echo "			FastQC with sample file ${s} because ${f} not found"
				#/secondary/projects/genomicscore/tools/fastqc/FastQC/fastqc --outdir ${basecalls_dir}${p}/FastQC -t 16 ${basecalls_dir}${p}/*_L000_*
				/secondary/projects/genomicscore/tools/fastqc/FastQC/fastqc --outdir ${basecalls_dir}${p}/FastQC -t 16 ${basecalls_dir}${p}/${s}
			else
				echo "			FastQC with sample file ${s} exists (${f})"
			fi
		done
	else
		echo "	No L000 files to do FASTQC on ???"
	fi
done
##### FASTQC on Undetermined
echo "INFORMATION:"
if [ ! -f ${basecalls_dir}Undetermined_L000_R1_001_fastqc.html ]; then
	cd ${basecalls_dir}
	echo "	FastQC on the Undetermined."
	/secondary/projects/genomicscore/tools/fastqc/FastQC/fastqc -t 16 *_L000_*
else
	echo "	FastQC on the Undetermined exists!"
fi
##### MULTIQC
echo "INFORMATION:"
echo "	MultiQC..."
cd ${basecalls_dir}
#~ for p in `tail -n+20 ${PBS_O_WORKDIR}/SampleSheet.csv|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq`; do
	#~ if [ ! -f ${basecalls_dir}${p}/multiqc_report.html ]; then
		#~ echo "		Doing MultiQC for project ${p}!"
		#~ cd ${p}/
		#~ ln -sf ${basecalls_dir}Undetermined* .
		#~ export PATH=/secondary/projects/genomicscore/tools/miniconda2/bin:$PATH # not the best
		#~ multiqc .
		#~ cd ..
	#~ else
		#~ echo "		Not doing multiqc for project ${p} because the report exists."
	#~ fi
#~ done

cd $PBS_O_WORKDIR
diagf=${PBS_O_WORKDIR}/diagnostic_files/
mkdir -p ${diagf}
echo "
INFORMATION:
	Done with FastQC/MultiQC!
	Generating diagnostic files in ${diagf}
"

#=======================================================================
#======================================================================= get diagnostic files


#### Undetermined Index Quantification
index_summary=${diagf}IndexSummary.txt
echo "INFORMATION:"
if [ ! -f ${index_summary} ]; then
	echo "	Creating an index summary file \"${index_summary}\""
	/secondary/projects/genomicscore/tools/interop-build/src/apps/index-summary . > ${index_summary} # create index Summary for all lanes
else
	echo "	Index summary file \"${index_summary}\" exists"
fi

undetermined=${basecalls_dir}Undetermined_L000_R1_001.fastq.gz # check for the L000 file, these need to be in the BaseCall dir

echo "INFORMATION:"
if [ ! -f $undetermined ]; then
	echo "	Was going to quantify indexes in $undetermined, but I didn't find this file in ${basecalls_dir}"
	#~ cat ${messages}notgood2.message
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
for p in `cat ${PBS_O_WORKDIR}/SampleSheet.csv|grep -A1000 '^Lane'|grep -v '^Lane'|cut -d ',' -f${project_code_field}|grep -v '^$'|sort|uniq`; do
	mqc=${basecalls_dir}${p}/multiqc_report.html
	if [ -f $mqc ]; then
		ln -sf ${mqc} ${diagf}${p}_multiqc_report.html
	else
		echo "Did not find multiqc file for project \"${p}\" ($mqc)"
	fi
done








echo "INFORMATION:"
echo "	I'm done demultiplexing...goodbye..." 
