#!/usr/bin/perl

## Copyright Arnaud Dupuis <arnaud [dot] l [dot] dupuis [at] gmail [dot] com>
## License: GPLv3
## Version: 0.1s

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

sub loadConfig {
	my $cfg = shift;
	open(my $fh,'<',shift(@_)) or die $!;
	while(<$fh>){
		chomp;
		next if(/^[#\/!*]+/);
# 		print "Processing: $_\n";
# 		my ($key,$value)=split(/=/,$_);
		my ($key,$value)= $_ =~ /^([^=]+)\s*=\s*(.+)$/;
		$cfg->{$key} = $value unless(defined($cfg->{$key}));
	}
	close($fh);
}
sub loadFile {
	my $file = shift;
	my $content = "";
	open(my $fh,'<',$file) or die "$file: $!\n";
	while(<$fh>){
		$content .= $_;
	}
	close($fh);
	return $content;
}
sub writeFile {
	my $file = shift;
	my $data = shift;
	open(my $fh,'>',$file) or die "$file: $!\n";
	print $fh $data;
	close($fh);
}
my $config={templates_basedir=>'./templates'};
$config->{templates_basedir}=$ENV{KIGO_TEMPLATE_PATH} if(defined($ENV{KIGO_TEMPLATE_PATH}) && $ENV{KIGO_TEMPLATE_PATH});
print "templates base directory is: $config->{templates_basedir}\n";
my $members = {};
my $extra = {};
my $code_gen = {
	constructor_inline => "",
	constructor_body => "",
	includes => "",
	variables_declarations => "",
	getters_code => "",
	getters_headers => "",
	setters_code => "",
	setters_headers => "",
	signals_headers => "",
	property => "",
	extra_includes => "",
	copy_operator => ""
};
loadConfig($config,$ARGV[0]);
