#!/usr/bin/perl -w
use strict;
my $detection=shift @ARGV;
my $PF_reads=shift @ARGV;
my $file=shift @ARGV;
my $read2_length=shift @ARGV;

if($read2_length){
	print STDOUT "#Read 2 length was determined to be greater than 0\n";
	$PF_reads = $PF_reads * 2;
}
chomp($PF_reads);

open(my $in,'<',$file);
my %d=();
my $t=0; # total undetermined read count, get it by opening the file that has all of the undetermined barcodes:
while(<$in>){
	next if 1..1;
	chomp;
	my($c,$b)=split('\t',$_);
	$d{$b}=$c;
	$t+=$c;
}
print STDOUT "Barcode\tCount\tFractionOfTotal ($PF_reads)\tFractionOfUndetermined ($t)\n";
foreach my $b (keys %d){
	my $f = sprintf('%.10f', ($d{$b} / $PF_reads)); # total of PF_reads
	my $uf = sprintf('%.10f', ($d{$b} / $t)); # undetermined fraction
	if($f>$detection){
		print STDOUT "$b\t$d{$b}\t$f\t$uf\n";
	}
}







