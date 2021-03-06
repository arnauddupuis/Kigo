#!/usr/bin/perl

## Copyright Arnaud Dupuis <arnaud [dot] l [dot] dupuis [at] gmail [dot] com>
## License: GPLv3
## Version: 0.01

use strict;
use warnings;
use Getopt::Long;
use File::Path qw(make_path);
use File::Basename;
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

# This function loads the content of a .ktpl file removing the comments and return it as a single string.
sub loadKtpl {
	my $file = shift;
	my $content = "";
	open(my $fh,'<',$file) or die "$file: $!\n";
	while(<$fh>){
		next if( /^\s*#/ );
		$content .= $_;
	}
	close($fh);
	return $content;
}

# This function loads the content of a file removing the comments and return it as a single string.
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
my $templates_types_mapping = {};
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
						# Add dependencies to the stack of templates to load.
						if( defined( $templates->{$tmp_tpl}->{'content'}->{'use'} ) ){
							foreach my $tmp_use_tpl ( @{ $templates->{$tmp_tpl}->{'content'}->{'use'} } ){
								unless( grep{ $_ eq $tmp_use_tpl } @{ $config->{'templates'} } ){
									verbose "Adding '$tmp_use_tpl' to the list of templates to load.\n";
									push @{ $config->{'templates'} }, $tmp_use_tpl;
								}
							}
						}
						# Mapping template defined types
						if( defined( $templates->{$tmp_tpl}->{'content'}->{'types'} ) && ref($templates->{$tmp_tpl}->{'content'}->{'types'}) eq 'ARRAY' ){
							foreach my $tmp_type ( @{ $templates->{$tmp_tpl}->{'content'}->{'types'} } ){
								if( exists($templates_types_mapping->{$tmp_type}) && defined($templates_types_mapping->{$tmp_type}) && $templates_types_mapping->{$tmp_type} ne $tmp_tpl ){
									die "[critical] type '$tmp_type' is defined by more than one template (at minimum $templates_types_mapping->{$tmp_type} and $tmp_tpl).\n";
								}
								else {
									$templates_types_mapping->{$tmp_type} = $tmp_tpl;
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

# Verify config file coherence regarding the file to generate
my @available_templates_types = ();
foreach my $tmp_tpl ( keys( %{$templates} ) ){
	push @available_templates_types, @{ $templates->{$tmp_tpl}->{'content'}->{'types'} };
}
foreach my $to_generate_type ( @{ $config->{'generate'} } ){
	unless( grep{ $_ eq $to_generate_type } @available_templates_types ){
		die "[critical] the file $ARGV[0] require to generate files of type '$to_generate_type' but this type is not defined in included templates.\n";
	}
}

debug Data::Dumper::Dumper( $config );
debug Data::Dumper::Dumper( $templates );
debug Data::Dumper::Dumper( $templates_types_mapping );


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
	'CLASS_NAME' => $config->{'class'},
	'CLASS_EXTRA_CONSTRUCTOR_CODE' => "",
	'CLASS_PARENT_CONSTRUCTION' => "",
	'CLASS_SKELETON' => "",
	'CONSTRUCTOR_PARAMETERS' => "",
	'EXTRA_TEMPLATES_PLACEHOLDER' => "",
	'GETTERS' => "",
	'INCLUDES' => [],
	'INHERITANCE' => [],
	'K_PARENT_CONSTRUCTION' => "",
	'K_PARENT_CONSTRUCTOR_PARAMETERS' => "",
	'LC_MEMBERNAME' => {}, # all 'membername' holds all the members for a class
	'LCF_MEMBERNAME' => {}, # all 'membername' holds all the members for a class
	'LICENSE' => "",
	'MEMBER_VARIABLES_DECLARATION' => "",
	'MEMBER_VARIABLES_INIT' => "",
	'SETTERS' => "",
	'UC_MEMBERNAME' => {}, # all 'membername' holds all the members for a class
	'UCF_MEMBERNAME' => {}, # all 'membername' holds all the members for a class
	'VARIABLES_DETAILS' => {},
};

# Parsing class name to look for inheritance
if( $variables_hold->{'CLASS_NAME'} =~ /^([^\:]+):([^\:]+)$/ ){
	verbose "Found inheritance for $1 (inherits from: $2).\n";
	$variables_hold->{'CLASS_NAME'} = $1;
	push @{ $variables_hold->{'INHERITANCE'} }, split(/;/,$2);
	
	if( defined( $templates->{$config->{'templates'}->[0]}->{'content'}->{'default'}->{'file_suffix'} ) && $templates->{$config->{'templates'}->[0]}->{'content'}->{'default'}->{'file_suffix'} ne "" ){
		unless( grep{ $_ eq $2.$templates->{$config->{'templates'}->[0]}->{'content'}->{'default'}->{'file_suffix'} } @{ $variables_hold->{'INCLUDES'} } ){
			push @{ $variables_hold->{'INCLUDES'} }, $2.$templates->{$config->{'templates'}->[0]}->{'content'}->{'default'}->{'file_suffix'};
		}
	}
	else{
		print "WARNING: class $variables_hold->{'CLASS_NAME'} needs a parent but we cannot determine the default file suffix for the default template ($config->{'templates'}->[0]).\n";
	}
}

# We now expand LC_MEMBERNAME, UCF_MEMBERNAME, UC_MEMBERNAME and LCF_MEMBERNAME
foreach my $tmp_member (@{ $config->{'members'} }){
	my $parsed_member = parseMember($tmp_member);
	debug Data::Dumper::Dumper( $parsed_member );
	$variables_hold->{'LC_MEMBERNAME'}->{$parsed_member->{'name'}} = lc($parsed_member->{'name'});
	$variables_hold->{'LCF_MEMBERNAME'}->{$parsed_member->{'name'}} = lcfirst($parsed_member->{'name'});
	$variables_hold->{'UC_MEMBERNAME'}->{$parsed_member->{'name'}} = uc($parsed_member->{'name'});
	$variables_hold->{'UCF_MEMBERNAME'}->{$parsed_member->{'name'}} = ucfirst($parsed_member->{'name'});
	$variables_hold->{'VARIABLES_DETAILS'}->{$parsed_member->{'name'}} = $parsed_member;
}

# Now loading the license
if( -e $config->{'license'} ){
	verbose "Loading license from: $config->{'license'}\n";
	$variables_hold->{'LICENSE'} = loadFile( $config->{'license'} );
}
elsif( -e dirname($ARGV[0])."/$config->{'license'}" ){
	verbose "Loading license from: ".dirname($ARGV[0])."/$config->{'license'}\n";
	$variables_hold->{'LICENSE'} = loadFile( dirname($ARGV[0])."/$config->{'license'}" );
}
else{
	verbose "Inserting license from description file.\n";
	$variables_hold->{'LICENSE'} = $config->{'license'};
}

debug "Variables hold: ", Data::Dumper::Dumper( $variables_hold );

# TODO
# Loading class skeleton if we have to generate a class.
# if(  ){
# 	
# }

foreach my $types_to_generate ( @{ $config->{'generate'} } ){
	debug "generate files for type: $types_to_generate (template: $templates_types_mapping->{$types_to_generate})\n";
	foreach my $arch_item ( keys( %{ $templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate} } ) ){
		debug "\t$arch_item => $templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{$arch_item}\n";
		if( $templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{'type'}->{$types_to_generate} eq "class"){
			# Setting default value for main_template
			$templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'main_template'} = "class.ktpl" unless( defined($templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'main_template'}) );
			# Setting default value for getter
			$templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'getter'} = "getter.ktpl" unless( defined($templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'getter'}) );
			# Setting default value for setter
			$templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'setter'} = "setter.ktpl" unless( defined($templates->{$templates_types_mapping->{$types_to_generate}}->{'content'}->{$types_to_generate}->{'setter'}) );
			debug ""
		}
	}
}



