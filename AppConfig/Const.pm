#============================================================================
#
# AppConfig::Const.pm
#
# Perl5 module defining (and optionally exporting) constants for use by
# other AppConfig::* modules.
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Copyright (C) 1997,1998 Canon Research Centre Europe Ltd.
# All Rights Reserved.
#
#----------------------------------------------------------------------------
#
# $Id: Const.pm,v 0.1 1998/10/08 19:31:34 abw Exp abw $
#
#============================================================================

package AppConfig::Const;

require 5.004;

use strict;
use vars qw( $VERSION @ISA @EXPORT_OK %EXPORT_TAGS @EXPAND);

# variable expansion constants
use constant EXPAND_NONE => 0;
use constant EXPAND_VAR  => 1;
use constant EXPAND_UID  => 2;
use constant EXPAND_ENV  => 4;
use constant EXPAND_ALL  => EXPAND_VAR | EXPAND_UID | EXPAND_ENV;
use constant EXPAND_WARN => 8;

$VERSION = sprintf("%d.%02d", q$Revision: 0.1 $ =~ /(\d+)\.(\d+)/);

# Exporter tagsets
@EXPAND      = qw(EXPAND_NONE EXPAND_VAR EXPAND_UID EXPAND_ENV 
                  EXPAND_ALL EXPAND_WARN);
@ISA         = qw(Exporter);
@EXPORT_OK   = @EXPAND;
%EXPORT_TAGS = (
    expand   => [ @EXPAND ]
);



1;

__END__

=head1 NAME

AppConfig::Const - Constant definitions for other AppConfig::* modules. 

=head1 SYNOPSIS

    use AppConfig::Const;

    use AppConfig::Const qw(:expand);

=head1 OVERVIEW

AppConfig::Const is a Perl5 module which defines and optionally exports
constants for use in other AppConfig::* modules and perl programs that
use them.

=head1 DESCRIPTION

=head2 USING THE AppConfig::Const MODULE

To import and use the AppConfig::Const module the following line should 
appear in your Perl script:

     use AppConfig::Const;

To import the EXPAND_* constants, specify ':expand' as an option:

    use AppConfig::Const ':expand';

=head2 CONSTANT DEFINITIONS

Constants defined in the AppConfig::Const module may be accessed
explicitly by package:

    use AppConfig::Const;
    print "EXPAND_VAR: ", $AppConfig::Const::EXPAND_VAR, "\n";

or by first importing a set of constants:

    use AppConfig::Const ':expand';
    print "EXPAND_VAR: ", EXPAND_VAR, "\n";

=item EXPAND_*

The ':expand' tagset defines the following constants:

    EXPAND_NONE
    EXPAND_VAR
    EXPAND_UID 
    EXPAND_ENV
    EXPAND_ALL       # EXPAND_VARS | EXPAND_UIDS | EXPAND_ENVS
    EXPAND_WARN

See AppConfig::File for details of the use of these constants.

=head1 AUTHOR

Andy Wardley, C<E<lt>abw@cre.canon.co.ukE<gt>>

Web Technology Group, Canon Research Centre Europe Ltd.

=head1 REVISION

$Revision: 0.1 $

=head1 COPYRIGHT

Copyright (C) 1998 Canon Research Centre Europe Ltd.  
All Rights Reserved.

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.

=head1 SEE ALSO

AppConfig, AppConfig::State, AppConfig::File, AppConfig::Args

=cut
