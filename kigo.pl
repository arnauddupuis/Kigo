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
my @global_valid_types = ('class','controller','api','db_table');
$|++;

sub verbose {
	print join('',@_) if($global_verbose);
}

sub debug {
	print "[debug] " . join('',@_) if($global_debug);
}

sub loadConfig {
	my $cfg = shift;
	my $file = shift;
	my $extra_tables_keys = shift;
	debug "\$extra_tables_keys: ", Data::Dumper::Dumper( $extra_tables_keys ), "\n";
	my @cfg_table_keys = ('templates','generate','members');
	push @cfg_table_keys, @{ $extra_tables_keys } if(defined($extra_tables_keys) && $extra_tables_keys && ref($extra_tables_keys) eq 'ARRAY');
	debug "List of all table keys: ", join( ', ', @cfg_table_keys ),"\n";
	open(my $fh,'<',$file) or die $!;
	while(<$fh>){
		chomp;
		next if(/^[#\/!*]+/);
		next if(/^\s*$/);
		debug "Processing: $_\n";
		my ($key,$value)= $_ =~ /^([^=]+)\s*=\s*(.+)$/;
		next unless(defined($value));
		$cfg->{$key} = $value unless(defined($cfg->{$key}));
	}
	close($fh);
	foreach my $tmp_key ( keys(%{$cfg}) ){
		# remove uninitialized keys
		delete $cfg->{$tmp_key} unless( defined( $tmp_key ) && $tmp_key ne '' );
		debug "$tmp_key : $cfg->{$tmp_key}\n";
		if( $cfg->{$tmp_key} =~ /;/ ){
			$cfg->{$tmp_key} = [split(/;/,$cfg->{$tmp_key})];
		}
		if( $tmp_key =~ /^([^:]+):([^:\s]+)$/){
			debug "   (group) $1 (var) $2\n";
			$cfg->{$1}->{$2} = $cfg->{$tmp_key};
			if( $cfg->{$1}->{$2} eq $cfg->{$tmp_key}){
				delete $cfg->{$tmp_key};
			}
		}
	}
	
	foreach my $tmp_tbl_key (@cfg_table_keys){
		if( exists( $cfg->{$tmp_tbl_key} ) ){
			debug "force change key '$tmp_tbl_key' to table\n";
			$cfg->{$tmp_tbl_key} = [] unless( defined( $cfg->{$tmp_tbl_key} ) );
			if( ref($cfg->{$tmp_tbl_key}) ne 'ARRAY'){
				$cfg->{$tmp_tbl_key} = [$cfg->{$tmp_tbl_key}];
			}
		}
	}
	
	# Changing all keys of the form doc:(get|set):var to $cfg->{doc}->{[gs]{1}et}->{var}
	foreach my $tmp_key ( grep { /^doc:[^:]+:[^:]+$/ } keys(%{$cfg}) ){
		debug "[DOC] got $tmp_key.\n";
		my @tmp_tbl_key = split(/:/, $tmp_key);
		$cfg->{$tmp_tbl_key[0]}->{$tmp_tbl_key[2]}->{$tmp_tbl_key[1]} = $cfg->{$tmp_key};
		if( exists($cfg->{$tmp_tbl_key[0]}->{$tmp_tbl_key[2]}->{$tmp_tbl_key[1]}) && defined($cfg->{$tmp_tbl_key[0]}->{$tmp_tbl_key[2]}->{$tmp_tbl_key[1]}) && $cfg->{$tmp_tbl_key[0]}->{$tmp_tbl_key[2]}->{$tmp_tbl_key[1]} eq $cfg->{$tmp_key}){
			delete($cfg->{$tmp_key});
		}
	}
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
	debug "Loading template '$file'\n";
	loadConfig($tpl_struct,$file,\@cfg_table_keys);
	# TODO: process each template key
	# NOTE: It looks done...
# 	foreach my $tmp_key ( keys(%{$tpl_struct}) ){
# 		# remove uninitialized keys
# 		delete $tpl_struct->{$tmp_key} unless( defined( $tmp_key ) && $tmp_key ne '' );
# 		debug "$tmp_key : $tpl_struct->{$tmp_key}\n";
# 		if( $tpl_struct->{$tmp_key} =~ /,/ ){
# 			$tpl_struct->{$tmp_key} = [split(/,/,$tpl_struct->{$tmp_key})];
# 		}
# 		if( $tmp_key =~ /^([^:]+):([^:\s]+)$/){
# 			debug "   (group) $1 (var) $2\n";
# 			$tpl_struct->{$1}->{$2} = $tpl_struct->{$tmp_key};
# 			if( $tpl_struct->{$1}->{$2} eq $tpl_struct->{$tmp_key}){
# 				delete $tpl_struct->{$tmp_key};
# 			}
# 		}
# 	}
	
# 	foreach my $tmp_tbl_key (@cfg_table_keys){
# 		$tpl_struct->{$tmp_tbl_key} = [] unless( defined( $tpl_struct->{$tmp_tbl_key} ) );
# 		if( ref($tpl_struct->{$tmp_tbl_key}) ne 'ARRAY'){
# 			$tpl_struct->{$tmp_tbl_key} = [$tpl_struct->{$tmp_tbl_key}];
# 		}
# 	}
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
			return $status_struct;
		}
	}
	else{
		verbose "not ok\n";
		$status_struct->{'is_sanity_ok'}=0;
		$status_struct->{'error_string'}="Template must define at least one type to be valid. None found.";
		return $status_struct;
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
		# output directory checking
		if( defined($tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type})){
			verbose "sanity check: output:$type...ok\n";
		}
		else {
			verbose "sanity check: output:$type...not ok (adding default value: /$type)\n";
			$tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type} = "/$type";
		}
		push @output_directories, $tpl_struct->{$tpl_name}->{'content'}->{'output'}->{'root'}.$tpl_struct->{$tpl_name}->{'content'}->{'output'}->{$type};
		
		# Type consistancy checking
		if( exists($tpl_struct->{$tpl_name}->{'content'}->{'type'}->{$type}) && grep{ $_ eq $tpl_struct->{$tpl_name}->{'content'}->{'type'}->{$type} } @global_valid_types  ){
			verbose "sanity check: $type of type '$tpl_struct->{$tpl_name}->{'content'}->{'type'}->{$type}' is a valid one\n";
		}
		else{
			$status_struct->{'is_sanity_ok'}=0;
			$status_struct->{'error_string'}="$type is declared as a '$tpl_struct->{$tpl_name}->{'content'}->{'type'}->{$type}', wich is not a valid types. Valid types are: ".join(',',@global_valid_types);
			return $status_struct;
		}
		
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
			return $status_struct;
		}
	}
	
	return $status_struct;
}

sub parseMember {
	my $member = shift;
	my $return_value = {
		name => '',
		type => '',
		classinfo => '',
		extra => ''
	};
	if($member =~ /^([^{]+)\{([^}]+)\}$/){
		debug "Processing key=$1 & value=$2\n";
		$return_value->{name} = $1;
		$return_value->{type} = $2;
		
	}
	elsif($member =~ /^([^{]+)\{([^}]+)\}\{([^}]+)\}$/){
		debug "Processing key=$1 & value=$2 & extra=$3\n";
		$return_value->{name}  = $1;
		$return_value->{type}  = $2;
		$return_value->{extra} = $3;
	}
	elsif($member =~ /^([^{]+)\{([^}]+)\}\{([^}]+)\}\{([^}]+)\}$/){
		debug "Processing key=$1 & value=$2 & extra=$3 extra2=$4\n";
		$return_value->{name}      = $1;
		$return_value->{type}      = $2;
		$return_value->{extra}     = $3;
		$return_value->{classinfo} = $4;
	}
	debug Data::Dumper::Dumper( $return_value );
	return $return_value;
}

## NOTE: Beginning of the main code

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

# For each template verify that it has all required files (at minimum a template.ini file)
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
			loadTemplate($templates->{$_}->{content},"$config->{templates_basedir}/$_/template.ini");
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

if( exists($config->{'templates'}) && ref($config->{'templates'}) eq 'ARRAY' && scalar( @{ $config->{'templates'} } ) >= 1 ){
	foreach my $code_template ( @{ $config->{'templates'} } ){
		verbose "Templates: $code_template\n";
		unless ( $ignore_sanity_check ){
			foreach my $tmp_tpl ( keys( %{$templates} ) ){
				if( $templates->{$tmp_tpl}->{'is_valid'} ){
					my $tpl_sanity;
					unless(defined($templates->{$tmp_tpl}->{'sanity_check'})){
						$tpl_sanity = verifyTemplateSanity($templates,$tmp_tpl);
						debug Data::Dumper::Dumper( $tpl_sanity );
						$templates->{$tmp_tpl}->{'sanity_check'} = $tpl_sanity;
					}
					else{
						$tpl_sanity = $templates->{$tmp_tpl}->{'sanity_check'};
					}
					if( $tpl_sanity->{is_sanity_ok} ){
						verbose "$tmp_tpl: sanity check...ok\n";
						if( defined( $templates->{$tmp_tpl}->{'content'}->{'use'} ) ){
							foreach my $tmp_use_tpl ( @{ $templates->{$tmp_tpl}->{'content'}->{'use'} } ){
								unless( grep{ $_ eq $tmp_use_tpl } @{ $config->{'templates'} } ){
									verbose "Adding '$tmp_use_tpl' to the list of templates to load.\n";
									push @{ $config->{'templates'} }, $tmp_use_tpl;
								}
							}
						}
						
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
	}
}
else {
	die "[critical] the file $ARGV[0] does not defines any templates to use or was incorrectly parsed.\n";
}

debug Data::Dumper::Dumper( $config );
debug Data::Dumper::Dumper( $templates );


verbose "Checking for templates usage in input file (this will check for templates used by the input file and check each template's dependencies).\n";

# I need to reparse this because now I have the sanity status for all templates.
foreach my $tmp_tpl ( keys( %{$templates} ) ) {
	foreach my $used_tpl ( @{ $templates->{$tmp_tpl}->{'content'}->{'use'} } ){
		verbose "Checking for template: '$used_tpl' (used by template '$tmp_tpl')...";
		die "not ok\n[critical] Template '$used_tpl' is required by template '$tmp_tpl' but was not found.\n" unless( exists( $templates->{$used_tpl} ) );
		die "not ok\n[critical] Template '$used_tpl' is required by template '$tmp_tpl' but is not valid.\n" unless( exists( $templates->{$used_tpl}->{'is_valid'} ) && $templates->{$used_tpl}->{'is_valid'} );
		die "not ok\n[critical] Template '$used_tpl' is required by template '$tmp_tpl' but did not pass sanity checks ($templates->{$used_tpl}->{'sanity_check'}->{'error_string'}).\n" unless( exists( $templates->{$used_tpl}->{'sanity_check'} ) && $templates->{$used_tpl}->{'sanity_check'}->{'is_sanity_ok'} );
		verbose "ok\n";
	}
}

# Now that the templates are good enough to be use, we need to expand the variables we will use.
my $variables_hold = {
	'K_PARENT_CONSTRUCTION' => "",
	'K_PARENT_CONSTRUCTOR_PARAMETERS' => "",
	'LC_MEMBERNAME' => {}, # all 'membername' holds all the members for a class
	'UCF_MEMBERNAME' => {},
	'LICENCE' => "",
	'INCLUDES' => "",
	'CLASS_NAME' => $config->{'class'},
	'INHERITANCE' => "",
	'MEMBER_VARIABLES_DECLARATION' => "",
	'CONSTRUCTOR_PARAMETERS' => "",
	'CLASS_PARENT_CONSTRUCTION' => "",
	'MEMBER_VARIABLES_INIT' => "",
	'CLASS_EXTRA_CONSTRUCTOR_CODE' => "",
	'SETTERS' => "",
	'GETTERS' => "",
	'EXTRA_TEMPLATES_PLACEHOLDER' => "",
};