#!/usr/bin/perl


# This is an improved version that will merge all samples (can have some samples on one lane and not on the other)

# this is the file hash:
my %files=();

# read in the sample sheet
#~ print "ARGUMENTS: ",join('|',@ARGV),"\n";
my $samplesheet = shift @ARGV;
my $read2_number_of_cycles = shift @ARGV;
my $machine = shift @ARGV;
my $run_dir = shift @ARGV;
chomp($read2_number_of_cycles);
$read2_number_of_cycles =~ s/[\r\n]+$//;
chomp($machine);
$machine =~ s/[\r\n]+$//;
chomp($run_dir);
$run_dir =~ s/[\r\n]+$//;
#~ print "The machinge i received is |$machine| |$machine2|\n";
#~ exit;

my $trigger=0; # triggers reading of samples
open(my $in,'<',$samplesheet)||die print "Cannot open the sample sheet: $samplesheet\n";
my %sample_number=();
my $sample_counter=1;
my $nlanes=0;
my %samples_fail_qc=();
while(<$in>){
	if($_=~/^Lane,Sa/ || $_=~/^Sample_ID,Sa/){ # works with Novaseq, MiniSeq & NextSeq sample sheets 
		$trigger=1;
		next;
	}
	if($_=~/^,/){next;} # blanks at the end of a samplesheet
	if($trigger){
		my($lane,$sample,$Sample_Name,$Sample_Plate,$Sample_Well,$I7_Index_ID,$index,$I5_Index_ID,$index2,$Sample_Project,$Description);
		if($machine eq 'A00426'){ # Novaseq
			#~ print "NOVASEQ...\n";
			($lane,$sample,$Sample_Name,$Sample_Plate,$Sample_Well,$I7_Index_ID,$index,$I5_Index_ID,$index2,$Sample_Project,$Description) = split(',',$_);
		}elsif($machine eq 'MN01106'){ # MiniSeq
			#~ print "MINISEQ...\n";
			($lane,$sample,$Sample_Name,$Sample_Plate,$Sample_Well,$I7_Index_ID,$index,$I5_Index_ID,$index2,$Sample_Project,$Description) = split(',',$_);
		}elsif($machine eq 'NS500653'){ # NextSeq
			($sample,$Sample_Name,$Sample_Plate,$Sample_Well,$I7_Index_ID,$index,$I5_Index_ID,$index2,$Sample_Project,$Description) = split(',',$_);
			print "NEXTSEQ... sample: $sample\n";
			$nlanes=4;
		}else{
			die print "I don't recognize the machine |$machine|, (Not MiniSeq, NovaSeq, NextSeq) ??? \n";
		}
		
		if($machine ne 'NS500653'){ # If it is not a Nextseq run, then add each lane/sample combination
			if(exists $sample_number{$sample}){ # if counted already
				$files{$Sample_Project}{$sample}{$lane}=$sample_number{$sample};
			}else{ # if a new sample
				#~ print "Sample $sample_counter $sample is in project $Sample_Project\n";
				$sample_number{$sample}=$sample_counter;
				$files{$Sample_Project}{$sample}{$lane}=$sample_number{$sample};
				$sample_counter++; # increase
			}
		}else{ # if it is a Nextseq run, then there is no lane information in the sample sheet, but all samples are on 4 lanes
			$sample_number{$sample}=$sample_counter;
			for(my $i=1;$i<=$nlanes;$i++){
				print "Initiating $Sample_Project $sample Lane$i $sample_number{$sample}\n";
				$files{$Sample_Project}{$sample}{$i}=$sample_number{$sample};
			}
			$sample_counter++; # increase
		}
		# get max lanes
		if($lane>$nlanes){$nlanes=$lane}
	}
}
$sample_counter--;

my $nprojects = scalar keys %files;

# Report some numbers
print "MERGELANES INFORMATION:\n";
print "\tReceived $nprojects projects from $samplesheet.\n";
foreach my $p (keys %files){
	print "\t\tPROJECT: $p\n";
}

# Need to add Undetermined_S0 to the files with $Sample_Project '.', but do this AFTER we report the number of projects to minimize confusion
for(my $l=1;$l<=$nlanes;$l++){
	$files{'.'}{'Undetermined'}{$l}=0;
	$files{'.'}{'Undetermined'}{$l}=0;
}


print "\tReceived $read2_number_of_cycles read 2 cycles.\n";
print "\tExpect to merge lanes for $sample_counter samples (not including Undetermined).\n";
print "\tExpect $nlanes lanes.\n";
print "\tGoing to generate the L000 files\n";

my $number_samples_OK=0;
foreach my $p (sort keys %files){
	print "\nMERGELANES INFORMATION\n\tProject: $p\n";
	foreach my $s (sort keys %{$files{$p}}){
		my $ok=1;
		#~ print "_-^-"x25,"\n";
		my $expected_R2_L000;
		my $expected_R2_file="$p/$s\_L000_R2_001.fastq.gz";
		if($read2_number_of_cycles){
			if(-e $expected_R2_file){
				$expected_R2_L000=1;
			}else{
				$expected_R2_L000=0;
			}
		}else{
			$expected_R2_L000=1 # if no R2, then don't expect it & all is good
		}
		my $expected_file="$p/$s\_L000_R1_001.fastq.gz"; # expect an L000 file if done already, check if it exists before proceeding
		if(-e $expected_file && $expected_R2_L000){ # check if there is an R1 L000
			if($read2_number_of_cycles){
				print "\t\t$s	$expected_file	and $expected_R2_file exist\n";
			}else{
				print "\t\t$s	$expected_file exists\n";
			}
			$number_samples_OK++;
		}else{
			
			print "\t\tMerging ",scalar keys %{$files{$p}{$s}}," lane(s) from sample \"$s\"\n";
		
			foreach my $l (sort keys %{$files{$p}{$s}}){
				
				my $sample_number = $files{$p}{$s}{$l};
				print "\t\t\tL00$l\n";
				
				my $read=1;
				my $filename = "$p/$s\_S$sample_number\_L00$l\_R$read\_001.fastq.gz";
				if(-e $filename){
					my $cmd="cat $filename >> $p/$s\_L000_R$read\_001.fastq.gz";
					print "\t\t\t\tmerging R$read: $cmd\n";
					system($cmd);
					### system("cat $s\_S[[:digit:]]*\_L00$l\_R$read\_001.fastq.gz >> $s\_L000_R$read\_001.fastq.gz");
				}else{
					$ok=0;
					print "\t\t\t\tWARNING: There is no file \"$filename\"\n";
				}
				
				$read=2;
				$filename = "$p/$s\_S$sample_number\_L00$l\_R$read\_001.fastq.gz";			
				if($read2_number_of_cycles){
					if(-e $filename){
						my $cmd="cat $filename >> $p/$s\_L000_R$read\_001.fastq.gz";
						print "\t\t\t\tmerging R$read: $cmd\n";
						system($cmd);
						### system("cat $s\_S[[:digit:]]*\_L00$l\_R$read\_001.fastq.gz >> $s\_L000_R$read\_001.fastq.gz");
					}else{
						$ok=0;
						print "\t\t\t\tWARNING: There is no file \"$filename\"\n";
					}
				}else{
				}
			}
			if($ok){
				$number_samples_OK++;
			}else{
				$samples_fail_qc{"$p/$s"}=();
			}
		}

	}
}



my $expected_L000=$sample_counter+1;
if($number_samples_OK==$expected_L000){
	print "MERGELANES INFORMATION:\n\tQC PASS!\n\t$sample_counter L000 files for $sample_counter samples\n";
}else{
	print "MERGELANES INFORMATION:\n\tQC FAIL\n\tThere are $number_samples_OK L000 files, but I expected $expected_L000 L000 files ($sample_counter samples & an Undetermined).\n";
	foreach my $k (keys %samples_fail_qc){
		# delete L000 files for all samples that failed QC
		my $expected_file_R1="$k\_L000_R1_001.fastq.gz";
		my $expected_file_R2="$k\_L000_R2_001.fastq.gz";
		
		
		if($read2_number_of_cycles){
			print "\t\tsample $k FAILED\n\t\t\tdeleting $expected_file_R1\n\t\t\tdeleting $expected_file_R2\n";
			system("rm $expected_file_R1");
			system("rm $expected_file_R2");
		}else{
			print "\t\tsample $k FAILED\n\t\t\tdeleting $expected_file_R1\n";
			system("rm $expected_file_R1");
		}
		
		
	}
	my $error_file = $run_dir . "/mergelanes.failed";
	system("touch $error_file");
}



