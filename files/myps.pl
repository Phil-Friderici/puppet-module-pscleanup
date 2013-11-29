#!/usr/bin/perl
#
#
# Initialize
# Check if config file is given
if ($#ARGV != 0) {
	print STDERR "usage: $0 <config file>\n";
	exit 1;
}
$cfgfile=$ARGV[0];

# Does config file exist
if (! -f $cfgfile) {
	print STDERR "error: config file does not exist: $cfgfile\n";
	exit 1;
}


# Read config file
open cfgFD, "cat $cfgfile|";
while (<cfgFD>) {
	chomp;
	s/#.*//;
	s/\./\\\./;
	s/\*/\.\*/g;
	next if ( /^\s*$/ );
	/([^\s]*)\s*:\s*([^\s]*)/;
	$regexp.=$1."|";
}
chop $regexp;
#print STDOUT "REGEXP=$regexp\n";
close cfgFD;

open PS,"top -b -n 1|";
my $head=1;
while (<PS>) {
	chomp;
	s/^\s*//;
	my ($pid,$fname)=(split(/\s+/))[0,11];
	$fname=~s/\/\d*$//;
	next if ($pid !~ /^\d+$/);
	#

	if (length($fname) < 15) {
		next if ($fname !~ /^($regexp)$/);	
		print STDOUT "$pid $fname\n";
		next;
	}
	# Special for process names longer than 15
	#
	$args=`ps auxwwwwww $pid`;
	#$args=`$qps -A| grep "^$pid\ "`;
	next if ($? != 0); # PID died
 	#$fnew=($args=~/($fname[^\s^:]*)\s/g)[1];
 	$fnew=($args=~/($fname[^\s^:]*)\s/g)[0];
	if ($fnew eq "") {
		next if ($fname !~ /^($regexp)$/);	
		print STDOUT "$pid $fname\n";
	} else {
		next if ($fnew !~ /^($regexp)$/);	
		print STDOUT "$pid $fnew\n";
	}
}
close PS;

exit 0;
