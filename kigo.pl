#!/usr/bin/perl

## Copyright Arnaud Dupuis <arnaud [dot] l [dot] dupuis [at] gmail [dot] com>
## License: GPLv3
## Version: 0.01

use strict;
use warnings;
use Getopt::Long;
use File::Path qw(make_path);
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
	
	foreach my $tmp_tbl_key (@cfg_table_keys){
		$tpl_struct->{$tmp_tbl_key} = [] unless( defined( $tpl_struct->{$tmp_tbl_key} ) );
		if( ref($tpl_struct->{$tmp_tbl_key}) ne 'ARRAY'){
			$tpl_struct->{$tmp_tbl_key} = [$tpl_struct->{$tmp_tbl_key}];
		}
	}
}

sub verifyTemplateSanity {
	my $tpl_struct = shift;
	my $tpl_name = shift;
	my $status_struct = { is_sanity_ok => 1, error_string => "No error detected." };
	my @output_directories = ();
	
	verbose "$tpl_name: starting template.ini sanity checks.\n";
	# Template sanity check.
	verbose "sanity check: template defines at least one type...";
	if( defined($tpl_struct->{$tpl_name}->{'content'}->{'types'}) ){
		my $count = scalar( @{ $tpl_struct->{$tpl_name}->{'content'}->{'types'} } );
		if( $count >= 1 ){
			verbose "ok ($count type(s) defined)\n";
		}
		else {
			verbose "not ok\n";
			$status_struct->{'is_sanity_ok'}=0;
			$status_struct->{'error_string'}="Template must define at least one type to be valid. None found.";
		}
	}
	else{
		verbose "not ok\n";
		$status_struct->{'is_sanity_ok'}=0;
		$status_struct->{'error_string'}="Template must define at least one type to be valid. None found.";
	}
	
	
	# output directories
	if( defined($tpl_struct->{$tpl_name}->{'content'}->{'output'}->{'root'})){
		verbose "sanity check: output:root...ok\n";
	}
	else {
		verbose "sanity check: output:root...not ok (adding default value: ./generated_$tpl_name)\n";
		$tpl_struct->{$tpl_name}->{'content'}->{'output'}->{'root'} = './generated_'.$tpl_name;
	}
	foreach my $type ( @{ $tpl_struct->{$tpl_name}->{'content'}->{'types'} } ){
		if( defined($tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type})){
			verbose "sanity check: output:$type...ok\n";
		}
		else {
			verbose "sanity check: output:$type...not ok (adding default value: /$type)\n";
			$tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type} = "/$type";
		}
		push @output_directories, $tpl_struct->{$tpl_name}->{'content'}->{'output'}->{'root'}.$tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type}
	}
	debug "\@output_directories: ".join(',',@output_directories)."\n";
	verbose "sanity check: creating output directories.\n";
	make_path(@output_directories);
	foreach my $dir (@output_directories){
		verbose "sanity check: verifing $dir...";
		if( -e $dir && -d $dir){
			verbose "ok\n";
		}
		else{
			verbose "not ok\n";
			$status_struct->{'is_sanity_ok'}=0;
			$status_struct->{'error_string'}="Unable to create the $dir directory (it is possible that other directories could not be created, only the last failure will be shown).";
		}
	}
	# tables
	
	return $status_struct;
}

my $config={templates_basedir=>'./templates'};
my $templates = {};
my $ignore_sanity_check = 0;
$config->{templates_basedir}=$ENV{KIGO_TEMPLATE_PATH} if(defined($ENV{KIGO_TEMPLATE_PATH}) && $ENV{KIGO_TEMPLATE_PATH});
GetOptions ("define=s" => $config,"verbose"=>\$global_verbose, "debug"=>\$global_debug,"no-sanity-check"=>\$ignore_sanity_check);
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


debug Data::Dumper::Dumper( $templates );

unless ( $ignore_sanity_check ){
	foreach my $tmp_tpl ( keys( %{$templates} ) ){
		if( $templates->{$tmp_tpl}->{'is_valid'} ){
			my $tpl_sanity = verifyTemplateSanity($templates,$tmp_tpl);
			debug Data::Dumper::Dumper( $tpl_sanity );
			if( $tpl_sanity->{is_sanity_ok} ){
				verbose "$tmp_tpl: sanity check...ok\n";
			}
			else{
				print "[error] sanity check for template $tmp_tpl...not ok\n\tlast error: $tpl_sanity->{'error_string'}\n";
			}
		}
		else{
			verbose "$tmp_tpl: template sanity check not executed because the template is already marked as invalid.\n";
		}
	}
}
