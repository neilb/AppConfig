#========================================================================
#
# t/sys.t 
#
# AppConfig::Sys test file.
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
    print "1..3\n"; 
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

use AppConfig::Sys;
$loaded = 1;
ok(1);


#------------------------------------------------------------------------
# create two alternate AppConfig::Sys objects
#

my $sys    = AppConfig::Sys->new();            # auto-detect
my $winsys = AppConfig::Sys->new('Windows');

ok(defined $sys);
ok(defined $winsys);

$sys->_dump;
$winsys->_dump();

foreach my $s ($sys, $winsys) {
    print "- " x 36, "\n";
    print "          os: ", $s->os, "\n";
    print "     pathsep: ", $s->pathsep, "\n";
    print "can_getpwuid: ", $s->can_getpwuid(), "\n";
    print "    getpwuid: ", $s->getpwuid($<), "\n";
    print "    getpwuid: ", $s->getpwuid(), "\n";
    print "can_getpwnam: ", $s->can_getpwnam(), "\n";
    print "    getpwnam: ", $s->getpwnam('abw'), "\n";
    print "    getpwnam: ", $s->getpwnam(), "\n";
}

