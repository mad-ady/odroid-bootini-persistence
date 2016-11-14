#!/usr/bin/perl
use strict;
use warnings;
use Config::IniFiles;
use File::Copy;
use Data::Dumper;

#requirements:
# sudo apt-get install libconfig-inifiles-perl

#configuration
my $mediaboot = '/media/boot';
my $bootini = 'boot.ini';
my $bootinisum = '.boot.ini.md5sum';
my $config = '/etc/bootini-persistence.ini';

#load boot.ini's checksum
my $checksum = `md5sum $mediaboot/$bootini`;
$checksum = extractChecksum($checksum);
my $oldchecksum = 0;
if( -f "$mediaboot/$bootinisum"){
	if(open FILE, "$mediaboot/$bootinisum"){
		$oldchecksum = <FILE>;
		close FILE;
	}
	else{
		#checksum does not exist. Assume it's different
	}
}

#compare boot.ini's checksum with the older checksum
if( $checksum ne $oldchecksum ){
	logger("info", "$bootini has changed - will reapply user settings");	
	#read the config file with the user's settings and apply them one by one
	my %ini;
	tie %ini, 'Config::IniFiles', ( -file => "$config" );
	die "Unable to read $config" if (scalar keys %ini <= 1); #only the general section exists
	#print Dumper \%ini;

	#load boot.ini into an array and perform changes on it in memory
	my @boot;
	open BOOT, "$mediaboot/$bootini" or die $!;
	@boot=<BOOT>;
	close BOOT;
	logger("debug", "$bootini has ".(scalar @boot)." lines");

	#foreach section in boot.ini, apply changes in @boot
	foreach my $section (sort keys %ini){
		#iterate through all the lines in boot.ini until we have a match
		if(defined $ini{$section}{'match'} && defined $ini{$section}{'value'}){
			my $found = 0;
			logger("debug", "Processing parameter $section");
			for(my $i=0; $i<scalar(@boot); $i++){
				if($boot[$i]=~/$ini{$section}{'match'}/){
					$found = 1;
					my $original = $boot[$i];
					$original=~s/\r|\n//g; #cut out newlines
					logger("debug", "Matched original line $original");
					#replace the line with what you see in value
					$boot[$i]="setenv $section \"$ini{$section}{'value'}\"";
					logger("info", "Replacing <$original> with <$boot[$i]>");
					
				}
			}
			if(!$found){
				logger("error", "Unable to match section $section in $bootini. Check if the line exists or if the regular expression is correct");
			}
		}
		else{
			#incomplete config section. Silently ignored for now
		}
	}
	#make a backup of the original boot.ini, in case we f*ck up
	logger("info", "Making a backup of the original $mediaboot/$bootini as $mediaboot/$bootini.original");
	copy("$mediaboot/$bootini", "$mediaboot/$bootini.original") or die $!;
	
	#write the new boot.ini back to disk
	open BOOT, ">$mediaboot/$bootini" or die $!;
	foreach my $line (@boot){
		$line=~s/\r|\n//g; #trim newlines
		print BOOT "$line\n";
	}
	close BOOT;
	#recalculate bootini signature for next run
	$checksum = `md5sum $mediaboot/$bootini`;
	$checksum = extractChecksum($checksum);
	open FILE, ">$mediaboot/$bootinisum" or die $!;
	print FILE "$checksum";
	close FILE;
	logger("info", "Writing $bootini finished. Saved checksum $checksum");
}
else{
	logger("info", "$bootini has not changed. Nothing to do");
}

sub logger{
	my $severity = shift;
	my $message = shift;

	print `logger -s -t $0 -p "$severity" '$message'`;
}

sub extractChecksum{
	#extracts the checksum from a line like "c81947621cd0315ec76d5d7b5a1d8dd8  /media/boot/boot.ini"
	my $sum = shift;
	if($sum=~/([^\s]+)\s+/){
		return $1;
	}
}
