#========================================================================
#
# t/file.t 
#
# AppConfig::File test file.
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Copyright (C) 1998 Canon Research Centre Europe Ltd.
# All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#------------------------------------------------------------------------
#
# TODO
#
# * test PEDANTIC option
#
# * test EXPAND_WARN option
#
#========================================================================

use strict;
use vars qw($loaded);
$^W = 1;

BEGIN { 
    $| = 1; 
    print "1..10\n"; 
}

END {
    ok(0) unless $loaded;
}

my $ok_count = 1;
sub ok {
    shift or print "not ";
    print "ok $ok_count\n";
    ++$ok_count;
}

use AppConfig::Const ':expand';
use AppConfig::State;
use AppConfig::File;
$loaded = 1;
ok(1);


#------------------------------------------------------------------------
# create new AppConfig::State and AppConfig::File objects
#

my $state = AppConfig::State->new({
	    GLOBAL => { EXPAND => EXPAND_ALL },
	},
	'verbose',
	'html', 
	'same',
	'split',
	'cash' => { EXPAND => EXPAND_NONE },     # ignore '$' in cash
	'hdir' => { EXPAND => EXPAND_VAR  },     # expand only $vars
    );

# $state->_debug(1);

my $cfgfile = AppConfig::File->new($state);

# $state->_debug(0);

#2 - #3: test the state and cfgfile got instantiated correctly
ok(defined $state);
ok(defined $cfgfile);

#4: read the config file (from __DATA__)
ok($cfgfile->read(\*DATA));


#------------------------------------------------------------------------
#5 - #nn: test variable values got set with correct expansion
#

#5: html has no embedded variables
ok($state->html() eq 'public_html');

#6: cash should *not* be expanded (EXPAND_NONE) to protect '$'
ok($state->cash() eq 'I won $200!');

#7:  hdir expands variables ($html) but not uids (~)
ok($state->hdir() eq '~/public_html');

#8: see if "[~/$html]" matches "[${HOME}/$html]".  It may fail if your
#    platform doesn't provide getpwuid().  See AppConfig::Sys for details.
my ($one, $two) = 
    $state->same() =~ / \[ ( [^\]]+ ) \] \s+=>\s+ \[ ( [^\]]+ ) \]/gx;
ok($one = $two);

#9: test that "split" came out the same as "same"
ok($state->same() eq $state->split());

#10: test that "verbose" got set to 1 when no parameter was provided
ok($state->verbose() eq 1);




#========================================================================
# the rest of the file comprises the sample configuration information
# that gets read by read()
#

__DATA__
# lines starting with '#' are regarded as comments and are ignored
html = public_html
cash = I won $200!
hdir = ~/$html
same  = [~/$html] => [${HOME}/$html]
verbose

# the next line has a continutation, but should be treated the same
split = [~/$html] => \
[${HOME}/$html]


