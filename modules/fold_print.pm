use warnings;
use strict;

sub fn_fold_print {
### Given a message to print to the terminal, line-break that message at word breaks
### If any line begins with "```", this designates the start of no formatting
### If any line ends with "```", this designates the end of no formatting
### $_[0] is the message; $_[1] is the number of columns to use if columns can't be determined.
	### Determine how many columns we're working with
	my $v_columns;
	if( exists $ENV{PATH} && defined $ENV{PATH} ) {
		my @v_paths = split( m/:/, $ENV{PATH} );
		for ( @v_paths ) {
			if ( -f ( $_ . "/tput" ) && -x ( $_ . "/tput" ) ) {
				my $v_exe =  $_ . "/tput";
				$v_columns = `$v_exe cols`;
				chomp $v_columns;
				if ( $v_columns =~ m/^[0-9]+$/ ) {
					last;
				}
			}
		}
	}
	if ( $v_columns && $v_columns !~ m/^[0-9]+$/ ) {
		if ( $_[1] ) {
			$v_columns = $_[1];
		} else {
			return $_[0];
		}
	} else {
		$v_columns--;
	}

	### Go through each line of the message and make sure it's breaks appropriately
	my $b_noformat = 0;
	my $v_message = $_[0];
	if ( substr( $v_message, -1 ) ne "\n" ) {
		$v_message .= "\n";
	}
	my @v_message = split( m/\n/, $v_message . "last" );
	for my $_line ( @v_message ) {
		if ( $_line eq "" ) {
			$_line = "\n";
			next;
		}
		### What to do if we're removing formatting
		if ( ! $b_noformat && $_line =~ m/^```/ ) {
		### Recognize the start of no formatting
			$_line = substr( $_line, 3 );
			$b_noformat = 1;
			if ( $_line eq '' ) {
				next;
			}
		}
		if ($b_noformat) {
		### Recognize the end of no formatting
			if ( $_line =~ m/```$/ ) {
				$_line = substr( $_line, 0, -3 );
				$b_noformat = 0;
				if ( $_line eq '' ) {
					next;
				}
				$_line .= "\n";
				next;
			}
		}

		### If there is formatting, turn tabs into strings of spaces
		$_line =~ s/\t/     /g;
		### Find the number of spaces at the start of the line
		my $v_chars = 0;
		my $v_spaces = 0;
		my $v_char = substr( $_line, $v_chars, 1 );
		while ( $v_char =~ m/[ *\e-]/ ) {
			if ( $v_char eq "\e" ) {
				### If the current character is an escape, check if that escape starts a color
				my $v_color = substr( $_line, $v_chars );
				if ( $v_color =~ m/^\e\[[0-9;]+m/ ) {
					my $v_len = ( $+[0] - $-[0] );
					$v_chars += $v_len;
				} else {
					### If it doesn't, we've found the end of the spaces
					last;
				}
			} else {
				### For everything else, increase characters and spaces
				$v_chars++;
				$v_spaces++;
			}
			$v_char = substr( $_line, $v_chars, 1 );
		}
		### Replace spaces with newlines as close to line ends as possible
		my $b_pop = 0;
		my $v_columns = $v_columns - $v_spaces;
		while ( $v_chars < length($_line) ) {
			$v_char = substr( $_line, $v_chars, 1 );
			### If the breaking point was the start of a string of spaces, remove extra spaces
			while ( $v_char eq ' ' && $v_chars < length($_line) ) {
				$_line = substr( $_line, 0, $v_chars ) . substr( $_line, ($v_chars + 1) );
				$v_char = substr( $_line, $v_chars, 1 );
				if ( $v_chars == length($_line) ) {
					$b_pop = 1;
					last;
				}
			}
			my $v_length = 0;
			my $v_last_break = 0;
			my $v_since_last_break = 0;
			my $v_last_char = '';
			### Examine every character for however many columns we have available
			while ( $v_length <= $v_columns && $v_chars < length($_line) ) {
				$v_char = substr( $_line, $v_chars, 1 );
				### If it's an escape and it's the start of a color code, scoop that up, but don't add to the length
				if ( $v_char eq "\e" ) {
					my $v_color = substr( $_line, $v_chars );
					if ( $v_color =~ m/^\e\[[0-9;]+m/ ) {
						my $v_len = ( $+[0] - $-[0] );
						$v_chars += $v_len;
						$v_since_last_break += $v_len;
						next;
					} 
				}

				### If it's a space and the last character wasn't a space, we've discovered a new breaking point
				if ( $v_char eq ' ' && $v_last_char ne ' ' ) {
					$v_last_break = $v_length;
					$v_since_last_break = 0;
				} else {
					$v_since_last_break++
				}

				### prepare for the next character
				$v_length++;
				$v_chars++;
				$v_last_char = $v_char;
			}

			if ( $v_chars == length($_line) ) {
			### End if we're at the end of the line
				last;
			} elsif ( $v_last_break > 0 ) {
			### Break if we found a breaking point
				$v_chars -= $v_since_last_break;
				$_line = substr( $_line, 0, ($v_chars - 1) ) . "\n" . ( " " x $v_spaces ) . substr( $_line, $v_chars );
				$v_chars += $v_spaces;
			} else {
			### If we didn't find a breaking point, keep going until we do
				$v_char = substr( $_line, $v_chars, 1 );
				while ( $v_char ne ' ' && $v_chars < length($_line) ) {
					$v_chars++;
					$v_char = substr( $_line, $v_chars, 1 );
				}
				if ( $v_chars == length($_line) ) {
					last;
				}
				$_line = substr( $_line, 0, $v_chars ) . "\n" . ( " " x $v_spaces ) . substr( $_line, ($v_chars + 1) );
				$v_chars += $v_spaces + 1;
			}
		}
		if ($b_pop) {
		### If the last part of the line was all spaces, get rid of it
			my @line = split( m/\n/, $_line );
			pop(@line);
			$_line = join( "\n", @line );
		}
		$_line .= "\n";
	}
	pop(@v_message);
	return @v_message;
}

sub fn_print_files {
### Given a list of files, frint the contents of those files
### If the first argument starts with a space, a dash, or an asterisk, assume that it's not a file, and print that before the start of each line
	if (@_) {
		my $v_pre = '';
		if ( substr( $_[0], 0, 1 ) =~ m/[-* ]/ ) {
			$v_pre = shift(@_)
		}
		while (@_) {
			my $arg = shift(@_);
			if ( -f $arg && -r $arg && open( my $fh_read, "<", $arg ) ) {
				my $v_message = '';
				while (<$fh_read>) {
					$v_message .= $v_pre . $_;
				}
				print fn_fold_print($v_message);
			}
		}
	}
}

1;
