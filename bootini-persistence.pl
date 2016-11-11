#!/usr/bin/perl
use strict;
use warnings;
use Config::IniFiles;
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
	print Dumper \%ini;
	
}
else{
	logger("info", "$bootini has not changed. Nothing to do");
}

sub logger{
	my $severity = shift;
	my $message = shift;

	print `logger -s -t $0 -p "$severity" "$message"`;
}
