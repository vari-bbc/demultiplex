#PBS -l walltime=120:00:00
#PBS -l mem=90gb
#PBS -l nodes=1:ppn=16
#PBS -M your.email@vai.org
#PBS -m abe
#PBS -N 10x-demux
#PBS -W umask=0022

#Change into the directory the script was launched from
demux_dir=${PBS_O_WORKDIR}/
cd $demux_dir
echo "\\\\ Single-cell 10x demultiplexing ////"
echo "Run directory: $demux_dir"

#Export bcl2fastq
export PATH=$PATH:/secondary/projects/genomicscore/tools/bcl2fastq/default/bin # bcl2fastq was also too difficult to install as a module

#Load fastqc module
module load bbc/fastqc/fastqc-0.11.8

#Export multiqc
module load bbc/multiqc/multiqc-1.8

#Load cellranger
module load bbc/cellranger/cellranger-3.1.0
#module load bbc/cellranger/cellranger-4.0.0

# get the flowcell
flowcell=$(cat RunInfo.xml|grep '<Flowcell>'|sed -e 's/<Flowcell>//'|sed -e 's/<\/Flowcell>//'|sed -e 's/ //g'| sed $'s/\r//' | sed -e 's/\s*//g')

if [ ! -d $flowcell ]; then
	# using a simple samplesheet creates an expanded samplesheet in something like <run directory>/<flowcell?/MAKE_FASTQS_CS/MAKE_FASTQS/PREPARE_SAMPLESHEET/fork0/chnk0-ue95dc1ca02/files/samplesheet.csv
	
	echo "Demultiplexing"
		
	# w/o bases-mask option (worked for second run)
	cellranger mkfastq \
	--run=${demux_dir} \
	--csv=${demux_dir}SampleSheet.csv \
	--qc

else
	echo "Demultiplexing is done. If this is not the case, e.g. there was an error, then delete the ${flowcell} directory and resubmit the job."
fi

# FastQC
cd ${demux_dir}${flowcell}/outs/fastq_path/
mkdir -p FastQC

if [ ! -f FastQC/Undetermined_S0_L001_I1_001_fastqc.zip ]; then
	fastqc -t ${PBS_NUM_PPN} Undetermined*
	mv *.zip FastQC
	mv *.html FastQC
fi


cd ${flowcell} 

for sample_dir in `ls`; do
	# do fastqc
	echo "FastQC on ${sample_dir}"
	fastqc -t ${PBS_NUM_PPN} ${sample_dir}/*.fastq.gz

	mv ${sample_dir}/*.zip ../FastQC/
	mv ${sample_dir}/*.html ../FastQC/
	
done

cd ${demux_dir}${flowcell}/outs/fastq_path/


# Multiqc
echo "MultiQC!"
multiqc FastQC

