#========================================================================
#
# t/default.t 
#
# AppConfig::File test file.  Tests the '-option' syntax which is used 
# to reset variables to their default values.
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
    print "1..11\n"; 
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
$loaded = 1;
ok(1);


#------------------------------------------------------------------------
# create new AppConfig
#

my $BAZDEF = "all_bar_none";
my $BAZNEW = "new_bar";

my $config = AppConfig->new( { GLOBAL => { ARGCOUNT => 0 } },
	'foo', 
	'bar', 
	'baz' => { ARGCOUNT => 1, DEFAULT => $BAZDEF },
	'qux' => { ARGCOUNT => 1 },
    );

#2: test config got instantiated correctly
ok( defined $config );

#3 - #4: set some dummy values
ok( $config->foo(1)        );
ok( $config->baz($BAZNEW) );

#5 - #6: test them
ok( $config->foo() == 1       );
ok( $config->baz() eq $BAZNEW );

#7: read the config file (from __DATA__)
ok( $config->file(\*DATA) );

#8 - #9: test foo and baz got reset to defaults correctly
ok( $config->foo() == 0       );
ok( $config->baz() eq $BAZDEF );

#10 - #11: test that "+bar" and "+qux" worked
ok( $config->bar() ==  1  );
ok( $config->qux() eq '1' );

__DATA__
-foo
+bar
-baz
+qux

