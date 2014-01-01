#!/usr/bin/perl

## Copyright Arnaud Dupuis <arnaud [dot] l [dot] dupuis [at] gmail [dot] com>
## License: GPLv3
## Version: 0.01

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

# global variables (I know).
my $global_verbose=0;
my $global_debug=0;

sub verbose {
	print shift if($global_verbose);
}

sub debug {
	print "[debug] " . shift if($global_debug);
}

sub loadConfig {
	my $cfg = shift;
	open(my $fh,'<',shift(@_)) or die $!;
	while(<$fh>){
		chomp;
		next if(/^[#\/!*]+/);
		next if(/^\s*$/);
		verbose "Processing: $_\n";
		my ($key,$value)= $_ =~ /^([^=]+)\s*=\s*(.+)$/;
		next unless(defined($value));
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

sub loadTemplate {
	my $tpl_struct = shift;
	my $file = shift;
	my @cfg_table_keys = ('extra_includes','types','use');
	loadConfig($tpl_struct,$file);
	# TODO: process each template key
	# NOTE: It looks done...
	foreach my $tmp_key ( keys(%{$tpl_struct}) ){
		# remove uninitialized keys
		delete $tpl_struct->{$tmp_key} unless( defined( $tmp_key ) && $tmp_key ne '' );
		debug "$tmp_key : $tpl_struct->{$tmp_key}\n";
		if( $tpl_struct->{$tmp_key} =~ /,/ ){
			$tpl_struct->{$tmp_key} = [split(/,/,$tpl_struct->{$tmp_key})];
		}
		if( $tmp_key =~ /^([^:]+):([^:\s]+)$/){
			debug "   (group) $1 (var) $2\n";
			$tpl_struct->{$1}->{$2} = $tpl_struct->{$tmp_key};
			if( $tpl_struct->{$1}->{$2} eq $tpl_struct->{$tmp_key}){
				delete $tpl_struct->{$tmp_key};
			}
		}
	}
	verbose "starting template.ini sanity checks.\n";
	# Template sanity check.
	if( defined($tpl_struct->{'output'}->{'root'})){
		verbose "sanity check: output:root...ok\n";
	}
	else {
		verbose "sanity check: output:root...not ok\n";
		$tpl_struct->{''} = '';
	}
	
	# output directories
	
	# tables
	foreach my $tmp_tbl_key (@cfg_table_keys){
		$tpl_struct->{$tmp_tbl_key} = [] unless( defined( $tpl_struct->{$tmp_tbl_key} ) );
		if( ref($tpl_struct->{$tmp_tbl_key}) ne 'ARRAY'){
			$tpl_struct->{$tmp_tbl_key} = [$tpl_struct->{$tmp_tbl_key}];
		}
	}
}

my $config={templates_basedir=>'./templates'};
my $templates = {};
$config->{templates_basedir}=$ENV{KIGO_TEMPLATE_PATH} if(defined($ENV{KIGO_TEMPLATE_PATH}) && $ENV{KIGO_TEMPLATE_PATH});
GetOptions ("define=s" => $config,"verbose"=>\$global_verbose, "debug"=>\$global_debug);
verbose "templates base directory is: $config->{templates_basedir}\n";

verbose "Scanning available templates:\n";
opendir(my $dh, $config->{templates_basedir}) || die;
my @templates_list = grep { !/^\./ && -d "$config->{templates_basedir}/$_" } readdir $dh;
closedir $dh;
foreach (@templates_list){
	verbose "- $_";
	$templates->{$_} = {};
	# The template.ini file is required
	if( -e "$config->{templates_basedir}/$_/template.ini" ){
		
		if(-z "$config->{templates_basedir}/$_/template.ini" ){
			$templates->{$_}->{is_valid} = 0;
			$templates->{$_}->{last_error} = "template.ini looks empty !";
			verbose " (INVALID: template.ini looks empty !)";
		}
		elsif( ! -r "$config->{templates_basedir}/$_/template.ini" ){
			$templates->{$_}->{is_valid} = 0;
			$templates->{$_}->{last_error} = "template.ini looks unreadable !";
			verbose " (INVALID: template.ini looks unreadable !)";
		}
		else{
			$templates->{$_}->{is_valid} = 1;
			$templates->{$_}->{content}={};
			verbose " (Valid)";
		}
	}
	else{
		$templates->{$_}->{is_valid} = 0;
		$templates->{$_}->{last_error} = "miss template.ini !";
		verbose " (INVALID: miss template.ini !)";
	}
	verbose "\n";
}

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
die "[critical] You MUST pass a template file as argument." unless(defined($ARGV[0]));
loadConfig($config,$ARGV[0]);
verbose "Templates: $config->{templates}\n";
loadTemplate($templates->{$config->{templates}}->{content},"$config->{templates_basedir}/$config->{templates}/template.ini");
debug Data::Dumper::Dumper($templates);