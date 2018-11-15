#! /usr/bin/perl
### given a file name, or series of file names, or piped in data, fold print those files

use strict;
use warnings;

my $d_progdir = '####INSTALLATION_DIRECTORY####';

if ( substr($d_progdir, 0, 1) ne "/" ) {
	$d_progdir = __FILE__;
	$d_progdir = ( readlink($d_progdir) || $d_progdir );
	my @progdir = split( m/\//, $d_progdir );
	pop( @progdir );
	pop( @progdir );
	$d_progdir = join( "/", @progdir );
}

require( $d_progdir . '/modules/fold_print.pm' );

### First print anything piped in
if ( ! -t STDIN ) {
	my $v_message = '';
	while (<STDIN>) {
		$v_message .= $_;
	}
	print fn_fold_print($v_message);
}

### Then print any files that were given
if (@ARGV) {
	fn_print_files(@ARGV);
}
