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
    print "1..33\n"; 
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

use AppConfig qw(:expand :argcount);
use AppConfig::File;
$loaded = 1;
ok(1);


#------------------------------------------------------------------------
# create new AppConfig::State and AppConfig::File objects
#

my $state = AppConfig::State->new({
	    CREATE   => '^define_',
	    GLOBAL => { 
		EXPAND   => EXPAND_ALL,
		ARGCOUNT => ARGCOUNT_ONE,
	    },
	},
	'html', 
	'same',
	'split',
	'title', 'ident',
	'cash'    => { EXPAND => EXPAND_NONE },     # ignore '$' in cash
	'hdir'    => { EXPAND => EXPAND_VAR  },     # expand only $vars
	'verbose' => { ARGCOUNT => ARGCOUNT_NONE }, # simple flags..
	'cruft'   => { 
	    ARGCOUNT => ARGCOUNT_NONE,
	    DEFAULT  => 1,
	},
	'debug'   => {
	    ARGCOUNT => ARGCOUNT_NONE,
	    DEFAULT  => 1,
	}, 
	'chance'   => {
	    ARGCOUNT => ARGCOUNT_NONE,
	    DEFAULT  => 1,
	}, 
	'hope'   => {
	    ARGCOUNT => ARGCOUNT_NONE,
	    DEFAULT  => 1,
	}, 
	'drink'  => {
	    ARGCOUNT => ARGCOUNT_LIST,
	},
	'name'  => {
	    ARGCOUNT => ARGCOUNT_HASH,
	},
    );

# turn debugging on to trigger debugging in $cfgfile
# $state->_debug(1);
my $cfgfile = AppConfig::File->new($state);

# AppConfig::State can be turned off, AppConfig::File debugging remains on.
# $state->_debug(0);

#2 - #3: test the state and cfgfile got instantiated correctly
ok( defined $state   );
ok( defined $cfgfile );

#4: read the config file (from __DATA__)
ok( $cfgfile->parse(\*DATA) );


#------------------------------------------------------------------------
#5 - #nn: test variable values got set with correct expansion
#

#5: html has no embedded variables
ok( $state->html() eq 'public_html' );

#6: cash should *not* be expanded (EXPAND_NONE) to protect '$'
ok( $state->cash() eq 'I won $200!' );

#7:  hdir expands variables ($html) but not uids (~)
ok( $state->hdir() eq '~/public_html' );

#8: see if "[~/$html]" matches "[${HOME}/$html]".  It may fail if your
#   platform doesn't provide getpwuid().  See AppConfig::Sys for details.
my ($one, $two) = 
    $state->same() =~ / \[ ( [^\]]+ ) \] \s+=>\s+ \[ ( [^\]]+ ) \]/gx;
ok( $one = $two );

#9: test that "split" came out the same as "same"
ok( $state->same() eq $state->split() );

#10: test that "verbose" got set to 1 when no parameter was provided
ok( $state->verbose() eq 1 );

#11: test that debug got turned off by explicit (debug = 0)
ok( ! $state->debug() );

#12 - #13: test that cruft got turned off by "nocruft"
ok( ! $state->cruft()   );
ok(   $state->nocruft() );

#14 - #15: test that chance got turned on by "nochance = 0"
ok(   $state->chance()   );
ok( ! $state->nochance() );

#16 - #17: test that hope got turned on by "nohope = off"
ok(   $state->hope()   );
ok( ! $state->nohope() );

#18 - #20: check auto-creation of variables and variable expansion of
#          [block] variable
ok( $state->define_user() eq 'abw'       );
ok( $state->define_home() eq '/home/abw' );
ok( $state->define_chez() eq '/chez/abw' );

#21 - #22: test $state->varlist() without strip option
my (%set, $expect, $got);
%set    = $state->varlist('^define_');
$expect = 'define_chez=/chez/abw, define_home=/home/abw, define_user=abw';
$got    = join(', ', map { "$_=$set{$_}" } sort keys %set);

ok( scalar keys %set == 3);
ok( $expect eq $got );

#23 - #24: test $state->varlist() with strip option
%set    = $state->varlist('^define_', 1);
$expect = 'chez=/chez/abw, home=/home/abw, user=abw';
$got    = join(', ', map { "$_=$set{$_}" } sort keys %set);

ok( scalar keys %set == 3);
ok( $expect eq $got );

#25 - #27: test ARGCOUNT_LIST
my $drink = $state->drink();
ok( $drink->[0] eq 'coffee');
ok( $drink->[1] eq 'beer');
ok( $drink->[2] eq 'water');

#28 - #31: test ARGCOUNT_HASH
my $name = $state->name();
my $crew = join(", ", sort keys %$name);
ok( $crew eq "abw, mim, mrp" );
ok( $name->{'abw'} eq 'Andy'           );
ok( $name->{'mrp'} eq 'Martin'          );
ok( $name->{'mim'} eq 'Man in the Moon' );

#32 - #33: test quoting
ok( $state->title eq "Lord of the Rings");
ok( $state->ident eq "Keeper of the Scrolls");



#========================================================================
# the rest of the file comprises the sample configuration information
# that gets read by parse()
#

__DATA__
# lines starting with '#' are regarded as comments and are ignored
html = public_html
cash = I won $200!
hdir = ~/$html
same  = [~/$html] => [${HOME}/$html]
verbose
debug = 0
nocruft

# this next one should turn chance ON (equivalent to "chance = 1")
nochance = 0
nohope   = off

# the next line has a continutation, but should be treated the same
split = [~/$html] => \
[${HOME}/$html]

# test list definitions
drink coffee
drink beer
drink water

# test hash definitions
name   abw = Andy
name   mrp = Martin
name = mim = "Man in the Moon"

# test quoting
title = "Lord of the Rings"
ident = 'Keeper of the Scrolls'

[define]
user = abw
home = /home/$user
chez = /chez/$define_user




