#PBS -l walltime=100:00:00
#PBS -l mem=90gb
#PBS -l nodes=1:ppn=8
#PBS -m abe
#PBS -N tarball
#PBS -W umask=0022

# usage: qsub -q genomics demultiplex/tarball.sh -M your.email@vai.org -F "jiracode"
if [ -z "$1" ]
then
    echo "Please provide jira code."
    echo 'Usage: qsub -q genomics demultiplex/tarball.sh -M your.email@vai.org -F "jiracode"'
    exit
else
    jiracode=$1
fi

cd ${PBS_O_WORKDIR} #Change into the run directory

module load bbc/pigz/pigz-2.4 

if [[ -d "$jiracode" ]]; then
    tar -vcf - $jiracode | pigz -p ${PBS_NUM_PPN} > ${jiracode}.tar.gz
    md5sum ${jiracode}.tar.gz > ${jiracode}.txt
else
    echo "${jiracode} directory does not exist in ${PBS_O_WORKDIR}"
fi
