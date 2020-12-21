#!/usr/bin/perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section section] [--debug] [file.sfm]";
# perl ./MrgEntSns.pl
use 5.026;
use strict;
use warnings;
use English;
use Data::Dumper qw(Dumper);
use utf8;
use open qw/:std :utf8/;
use File::Basename;
my $scriptname = fileparse($0, qr/\.[^.]*/); # script name without the .pl

use XML::LibXML;

use Getopt::Long;
GetOptions (
	'inifile:s'   => \(my $inifilename = "MrgEntSns.ini"), # ini filename
	'section:s'   => \(my $inisection = "MergeEntrySense"), # section of ini file to use
	'debug'       => \my $debug,
	) or die $USAGE;

use Config::Tiny;

say STDERR "read config from:$inifilename";
my $config = Config::Tiny->read($inifilename, 'crlf');
die "Couldn't find the INI file\nQuitting" if !$config;

my $infilename = $config->{"$inisection"}->{FwdataIn};
my $lockfile = $infilename . '.lock' ;
die "A lockfile exists: $lockfile\
Don't run $0 when FW is running.\
Run it on a copy of the project, not the original!\
I'm quitting" if -f $lockfile ;

my $outfilename = $config->{"$inisection"}->{FwdataOut};

my $liftfilename = $config->{"$inisection"}->{liftfilename};
open(LOGFILE, '>:encoding(UTF-8)', $config->{"$inisection"}->{logfilename});
say STDERR "Log file: ", $config->{"$inisection"}->{logfilename};
open(ERRFILE, '>:encoding(UTF-8)', $config->{"$inisection"}->{errorlogfilename});
say STDERR "Error Log file: ", $config->{"$inisection"}->{errorlogfilename};

say STDERR "Reading fwdata file: $infilename";
my $fwdatatree = XML::LibXML->load_xml(location => $infilename);

my %rthash;
foreach my $rt ($fwdatatree->findnodes(q#//rt#)) {
	my $guid = $rt->getAttribute('guid');
	$rthash{$guid} = $rt;
	}
my $size = keys %rthash;
say STDERR "$size rt entries";

say STDERR "Reading lift file: $liftfilename";
my $lifttree = XML::LibXML->load_xml(location => $liftfilename);

my %enthash; # LIFT file entries hashed by form+homograph
foreach my $entry ($lifttree->findnodes(q#//entry#)) {
	my ($formhm) = split(/_/,$entry->getAttribute('id'));
	$enthash{$formhm} = $entry;
	}

$size = keys %enthash;
say STDERR "$size Lift entries";
foreach my $entry ($lifttree->findnodes(q#//entry[@order="2"]#)) {
	my ($form) = split(/2_/,$entry->getAttribute('id'));
	if (exists $enthash{$form . "3"}) {
		say ERRFILE qq("${form}3" exists.  Won't process.);
		next;
		}
	if (!exists $enthash{$form . "1"}) {
		say ERRFILE qq("${form}1" does not exist.  Won't process.);
		next;
		}
	if ($enthash{$form . "1"}->findvalue(q#count(.//sense)#) != 1) {
		say ERRFILE qq#"${form}1" doesn't have single sense.  Won't process.#;
		next;
	}
	if ($enthash{$form . "2"}->findvalue(q#count(.//sense)#) != 1) {
		say ERRFILE qq#"${form}2" doesn't have single sense. Won't process.#;
		next;
		}

	if ($enthash{$form . "1"}->findvalue(q#count(.//relation[@type="_component-lexeme"])#) != 1) {
		say ERRFILE qq("${form}1" doesn't have single component.  Won't process.);
		next;
		}
	if ($enthash{$form . "2"}->findvalue(q#count(.//relation[@type="_component-lexeme"])#) != 1) {
		say ERRFILE qq("${form}2" doesn't have single component.  Won't process.);
		next;
		}

	if ($enthash{$form . "1"}->findnodes(q#./field[@type="import-residue"]#)) {
		say ERRFILE qq("${form}1" has an entry level Import Residue.  Won't process.);
		next;
		}

	if ($enthash{$form . "2"}->findnodes(q#./field[@type="import-residue"]#)) {
		say ERRFILE qq("${form}2" has an entry level Import Residue.  Won't process.);
		next;
		}

	if ($enthash{$form . "1"}->findnodes(q#./sense/field[@type="import-residue"]#)) {
		say ERRFILE qq("${form}1" has a sense level Import Residue.  Won't process.);
		next;
		}

	if ($enthash{$form . "2"}->findnodes(q#./sense/field[@type="import-residue"]#)) {
		say ERRFILE qq("${form}2" has a sense level Import Residue.  Won't process.);
		next;
		}

	my $guid1 = ($enthash{$form . "1"})->getAttribute('guid');
	my $guid2 = ($enthash{$form . "2"})->getAttribute('guid');
	next if !($guid1 =~ /(465372c6|fdd5d56a)/);
	say STDERR "found $MATCH";
	say STDERR "guid1 $guid1";
	say STDERR "guid2 $guid2";
=pod
	my ($x) = $entry->findnodes("./form/test/text()");
	say "x:$x";
	say "==== Before 1====";
	say "==== Before 2====";
	say $rthash{$guid2};
	say "==== Working====";
=cut
	my ($definition1) = $enthash{$form . "1"}->findnodes(q#./sense/definition/form/text/text()#);
	my ($definition2) = $enthash{$form . "2"}->findnodes(q#./sense/definition/form/text/text()#);
	if (!$definition1 ||  !$definition2) {
		say ERRFILE "$form missing definition in homograph 1. Won't process." if !$definition1;
		say ERRFILE "$form missing definition in homograph 2. Won't process." if !$definition2;
		next;
		}
	if ($definition1 ne  $definition2) {
		say ERRFILE "$form definitions differ in homographs 1 and 2. Won't process.";
		next;
		}

	my ($hmnode) = $rthash{$guid1}->findnodes(qq#./HomographNumber#);
	$hmnode->setAttribute( "val", 0 );
#	say STDERR $hmnode;
	my $rt1 = $rthash{$guid1};
	my $rt2 = $rthash{$guid2};
=pod
	my $irnode= $rt1->findnodes('./ImportResidue')->[0];
	my ($x) = $entry->findnodes("./form/test/text()");
	say "x:$x";
	say "==== Before 1====";
	say "==== Before 2====";
	say $rthash{$guid2};
	say "==== Working====";

	if ($irnode) {

		}
	else {
		}
=cut
	#say STDERR "modifying ImportResidue";
	my $irText = '<ImportResidue><Str><Run ws="en">merged false homograph</Run></Str></ImportResidue>';
	my $newnode = XML::LibXML->load_xml(string => $irText)->findnodes('//*')->[0];	
	$hmnode->addSibling($newnode);

	my ($entref1) = $rt1->findnodes(qq#./EntryRefs/objsur#);
	my ($entref2) = $rt2->findnodes(qq#./EntryRefs/objsur#);
	my $text = ($entref2->toString);
	$text =~ s/\r*\n//g;
#	say STDERR "entref1 $entref1";
#	say STDERR "entref2 as string  $text";
	$newnode = XML::LibXML->load_xml(string => $text)->findnodes('//*')->[0];
	$entref1->addSibling($newnode);

	my ($entry1sense) = $rt1->findnodes(qq#./Senses/objsur#);
	my ($entry2sense) = $rt2->findnodes(qq#./Senses/objsur#);
	#say STDERR "entry1sense $entry1sense";
	#say STDERR "entry2sense $entry2sense";
	$text = ($entry2sense->toString);
	$text =~ s/\r*\n//g;
	$newnode = XML::LibXML->load_xml(string => $text)->findnodes('//*')->[0];
	$entry1sense->addSibling($newnode);
	#say STDERR $rthash{$guid1};
# finished changing entry1 itself

#change lexsense2
	my $entry1senseguid = $entry1sense->getAttribute('guid');
	my $entry2senseguid = $entry2sense->getAttribute('guid');
	my $entry1lexsense =$rthash{$entry1senseguid};
	my $entry2lexsense =$rthash{$entry2senseguid};
	#say STDERR " before";
	#say STDERR $entry2lexsense;

	$entry2lexsense->setAttribute( "ownerguid", $guid1);
	my ($entry1lexsenseMSAobjsur) = $entry1lexsense->findnodes("./MorphoSyntaxAnalysis/objsur");
	my $entry1lexsenseMSAobjsurguid = $entry1lexsenseMSAobjsur->getAttribute('guid');
	my ($entry2lexsenseMSAobjsur) = $entry2lexsense->findnodes("./MorphoSyntaxAnalysis/objsur");
	$entry2lexsenseMSAobjsur->setAttribute( 'guid', $entry1lexsenseMSAobjsurguid);
	#entry2 Lexsense ownerguid & MorphoSyntaxAnalysis/objsur changed
	#say STDERR $entry2lexsense;

	my $entrguid = $entref2->getAttribute( 'guid' );
	$rthash{$entrguid}->setAttribute( 'ownerguid', $guid1);
# Entry1 stuff now corrected

# delete entry2's Lexemeform
	my ($lexemeform) =$rthash{$guid2}->findnodes(qq#./LexemeForm/objsur#);
	my $guid=$lexemeform->getAttribute('guid');
	#say STDERR "deleting entry2's Lexemeform $guid   ", $rthash{$guid};
	$rthash{$guid}->unbindNode();
	delete $rthash{$guid};

# delete entry2's first MorphoSyntaxAnalyses -- same as it's lexsense MorphoSyntaxAnalysis
	my ($msa) =$rthash{$guid2}->findnodes(qq#./MorphoSyntaxAnalyses/objsur#);
	$guid=$msa->getAttribute('guid');
	#say STDERR "deleting entry2's MorphoSyntaxAnalyses $guid    ", $rthash{$guid};
	$rthash{$guid}->unbindNode();
	delete $rthash{$guid};

# delete entry2
	$rthash{$guid2}->unbindNode();
	delete $rthash{$guid2};

	say LOGFILE qq("${form}" homograph 1 & 2 merged.);

# Delete duplicate sense (but only if simple --i.e. with nothing but definition)
	if ($enthash{$form . "1"}->findvalue(q#count(./sense/*)#) == 1) {
		my ($sensenode) = $enthash{$form . "1"}->findnodes(q#./sense#);
		my $senseguid = $sensenode->getAttribute('id');
		my $entryguid = $rthash{$senseguid}->getAttribute('ownerguid');
		my ($senseptrnode) =  $rthash{$entryguid}->findnodes(q#./Senses/objsur[@guid="# . $senseguid . q#"]#);
		$senseptrnode->unbindNode();
		$rthash{$senseguid}->unbindNode();
		delete $rthash{$senseguid};
		say LOGFILE "${form}1  sense deleted from merged record";
		}
	elsif ($enthash{$form . "2"}->findvalue(q#count(./sense/*)#) == 1) {
		my ($sensenode) = $enthash{$form . "2"}->findnodes(q#./sense#);
		my $senseguid = $sensenode->getAttribute('id');
		my $entryguid = $rthash{$senseguid}->getAttribute('ownerguid');
		my ($senseptrnode) =  $rthash{$entryguid}->findnodes(q#./Senses/objsur[@guid="# . $senseguid . q#"]#);
		$senseptrnode->unbindNode();
		$rthash{$senseguid}->unbindNode();
		delete $rthash{$senseguid};
		say LOGFILE "${form}2  sense deleted from merged record";
		}
	else {
		say LOGFILE "\"$form\" no simple sense found";
		};

	say STDERR "==== Done====";
	}

my $xmlstring = $fwdatatree->toString;
# Some miscellaneous Tidying differences
$xmlstring =~ s#><#>\n<#g;
$xmlstring =~ s#(<Run.*?)/\>#$1\>\</Run\>#g;
$xmlstring =~ s#/># />#g;
say STDERR "Finished processing, writing modified $outfilename" ;
open my $out_fh, '>:raw', $outfilename;
print {$out_fh} $xmlstring;
