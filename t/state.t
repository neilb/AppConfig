#========================================================================
#
# t/state.t 
#
# AppConfig::State test file.
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Copyright (C) 1998 Canon Research Centre Europe Ltd.
# All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use vars qw($loaded);
$^W = 1;

BEGIN { 
    $| = 1; 
    print "1..31\n"; 
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

use AppConfig::State;
$loaded = 1;
ok(1);


#------------------------------------------------------------------------
# define variables and handler subs
#

my $default = "<default>";
my $none    = "<none>";
my $user    = 'abw';
my $age     = 29;
my $verbose = 0;
my $errors  = 0;

# user validation routine
sub check_user {
    my $var = shift;
    my $val = shift;

    return ($val eq $user);
}

# verbose action routine
sub verbose {
    my $state = shift;
    my $var   = shift;
    my $val   = shift;

    # set global $verbose so we can test that this sub was called
    $verbose  = $val;

    # ok
    return 1;
}

sub error {
    my $format = shift;
    my @args   = @_;

    $errors++;
}

 
#------------------------------------------------------------------------
# define a new AppConfig::State object
#

my $state = AppConfig::State->new({ 
	ERROR  => \&error,
	GLOBAL => { 
	    DEFAULT  => $default,
	    ARGS     => 1,
	},
    },
    'verbose', {
       	DEFAULT  => 0,
	ACTION   => \&verbose,
	ARGS     => 0,
    },
    'user', {
	ALIAS    => 'name|uid',
	VALIDATE => \&check_user,
	DEFAULT  => $none,
    },
    'age', {
	VALIDATE => '\d+',
    });

# $state->_dump();
   

#------------------------------------------------------------------------
# check and manipulate variables
#

#2: check state got defined
ok(defined $state);

#3 - #5: check default values
ok($state->verbose() == 0);
ok($state->user() eq $none);
ok($state->age() eq $default);

#6 - #8: check ARGS got set explicitly or by default
ok($state->_args('verbose') == 0);
ok($state->_args('user') == 1);
ok($state->_args('age') == 1);

#9 - #11: set values and check they got set properly
$state->verbose(1);
ok($state->verbose() == 1);
$state->user($user);
ok($state->user() eq $user);
$state->age($age);
ok($state->age() == $age);

#12: test that the verbose ACTION was called and $verbose set
ok($verbose == 1);

#13 - #16: test the VALIDATE patterns/subs by attempting to set invalid values
ok(! $state->age('old'));
ok($state->age() == $age);
ok(! $state->user('dud'));
ok($state->user() eq $user);

#17: check that the error handler correctly updated $errors
ok($errors == 2);

#18 - #19: access variables via alias
ok($state->name() eq $user);
ok($state->uid() eq $user);

#20 - #22: test case insensitivity
ok($state->USER() eq $user);
ok($state->NAME() eq $user);
ok($state->UID() eq $user);

#23 - #24: explicitly test get() and set() methods
ok($state->set('verbose', 100));
ok($state->get('verbose') == 100);


#------------------------------------------------------------------------
# define a different AppConfig::State object
#

my $newstate = AppConfig::State->new({ 
	CASE     => 1,
	CREATE => '^define_',
	PEDANTIC => 1,
	ERROR    => \&error,
    });

#25: check state got defined
ok(defined $newstate);

#26 - #27: test CASE sensitivity
$errors = 0;
ok(! $newstate->Foo());
ok($errors);

#28 - #29: test PEDANTIC mode is/isn't set in states
ok(! $state->_pedantic());
ok($newstate->_pedantic());

#30 - #31: test auto-creation of define_ variable
ok($newstate->define_user($user));
ok($newstate->define_user() eq $user);

