#============================================================================
#
# AppConfig.pm
#
# Perl5 module for...
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Copyright (C) 1997,1998 Canon Research Centre Europe Ltd.
# All Rights Reserved.
#
#----------------------------------------------------------------------------
#
# $Id: AppConfig.pm,v 0.1 1998/10/08 20:34:52 abw Exp abw $
#
#============================================================================

package AppConfig;

require 5.004;

use AppConfig::State;

use strict;
use vars qw( $VERSION $AUTOLOAD );

$VERSION = sprintf("%d.%02d", q$Revision: 0.1 $ =~ /(\d+)\.(\d+)/);



#========================================================================
#                      -----  PUBLIC METHODS -----
#========================================================================

#========================================================================
#
# new(\%config, @vars)
#
# Module constructor.  All parameters passed are forwarded onto the 
# App::State constructor.
#
# Returns a reference to a newly created AppConfig object.
#
#========================================================================

sub new {
    my $class = shift;

    my $self = {
	STATE => AppConfig::State->new(@_)
    };

    bless $self, $class;
	
    return $self;
}



#========================================================================
#
# file(@files)
#
# The file() method is called to parse configuration files.  An 
# AppConfig::File object is instantiated and stored internally for
# use in subsequent calls to file().
#
# The parameters represent configuration files that should be processed.  
# The files should be specified by filename, or by passing a handle to 
# an open file.  These are then passed to the AppConfig::File object for
# processsing.
#
# Propagates the return value from AppConfig::File->read().
# 
#========================================================================

sub file {
    my $self  = shift;
    my $state = $self->{ STATE };
    my $file;


    require AppConfig::File;

    # create an AppConfig::File object if one isn't defined 
    $self->{ FILE } ||= ($file = AppConfig::File->new($state));

    # call on the AppConfig::File object to process files.
    $file->read(@_);
}



#========================================================================
#
# args(\@args)
#
# The args() method is called to parse command line arguments.  An 
# AppConfig::Args object is instantiated and then stored internally for
# use in subsequent calls to args().
#
# The parameter should be a reference to a list of arguments for 
# processing
#
# Propagates the return value from AppConfig::Args->args().
# 
#========================================================================

sub args {
    my $self  = shift;
    my $state = $self->{ STATE };
    my $args;


    require AppConfig::Args;

    # create an AppConfig::Args object if one isn't defined
    $self->{ ARGS } ||= ($args = AppConfig::Args->new($state));

    # call on the AppConfig::Args object to process arguments.
    $args->args(shift);
}


    
#========================================================================
#
# AUTOLOAD
#
# Autoload function called whenever an unresolved object method is 
# called.  All methods are delegated to the $self->{ STATE } 
# AppConfig::State object.
#
#========================================================================

sub AUTOLOAD {
    my $self = shift;
    my $method;


    # splat the leading package name
    ($method = $AUTOLOAD) =~ s/.*:://;

    # ignore destructor
    $method eq 'DESTROY' && return;

    # delegate method call to AppConfig::State object in $self->{ STATE } 
    $self->{ STATE }->$method(@_);
}




1;

__END__

=head1 NAME

AppConfig - Perl5 module for managing application configuration 
information, reading configuration files and parsing command line.

=head1 SYNOPSIS

    use AppConfig;

    # create a new AppConfig 
    my $config = AppConfig->new(\%cfg, @vardefs);

    # define a new variable
    $config->define($varname, \%varopts);

    # set/get the value
    $config->set($varname, $value);
    $config->get($varname);

    # shortcut form
    $config->varname($value);
    $config->varname();

    # read configuration file
    $config->file($file);

    # parse command line options
    $config->args(\@ARGV);

=head1 OVERVIEW

AppConfig is a Perl5 module to handle global configuration variables
for perl programs.  

It maintains the state of any number of variables, handling default 
values, aliasing, validation, update callbacks and option arguments 
for use by AppConfig::* modules.

The module handles the parsing of configuration files and command line
arguments.

=head1 PREREQUISITES

AppConfig requires Perl 5.004 or later.  

=head1 OBTAINING AND INSTALLING THE AppConfig MODULE BUNDLE

The AppConfig module bundle is available from CPAN.  As the 'perlmod' 
manual page explains:

    CPAN stands for the Comprehensive Perl Archive Network.
    This is a globally replicated collection of all known Perl
    materials, including hundreds of unbunded modules.  

    [...]

    For an up-to-date listing of CPAN sites, see
    http://www.perl.com/perl/ or ftp://ftp.perl.com/perl/ .

Within the CPAN archive, AppConfig is in the category:

    12) Option, Argument, Parameter and Configuration File Processing

The module is available in the following directories:

    /modules/by-module/AppConfig/AppConfig-<version>.tar.gz
    /authors/id/ABW/AppConfig-<version>.tar.gz

AppConfig is distributed as a single gzipped tar archive file:

    AppConfig-<version>.tar.gz

Note that "<version>" represents the current AppConfig Revision number, 
of the form "2.00".  See L<REVISION> below to determine the current 
version number for AppConfig.

Unpack the archive to create a AppConfig installation directory:

    gunzip AppConfig-<version>.tar.gz
    tar xvf AppConfig-<version>.tar

'cd' into that directory, make, test and install the modules:

    cd AppConfig-<version>
    perl Makefile.PL
    make
    make test
    make install

The 't' sub-directory contains a number of small sample files which are 
processed by the test script (called by 'make test').  See the README file 
in that directory for more information.  

The 'make install' will install the module on your system.  You may need 
root access to perform this task.  If you install the module in a local 
directory (for example, by executing "perl Makefile.PL LIB=~/lib" in the 
above - see C<perldoc MakeMaker> for full details), you will need to ensure 
that the PERL5LIB environment variable is set to include the location, or 
add a line to your scripts explicitly naming the library location:

    use lib '/local/path/to/lib';

The 'examples' sub-directory contains some simple examples of using the 
AppConfig modules.

=head1 DESCRIPTION

=head2 USING THE AppConfig MODULE

To import and use the AppConfig module the following line should 
appear in your Perl script:

     use AppConfig;

AppConfig is implemented using object-oriented methods.  A 
new AppConfig object is created and initialised using the 
new() method.  This returns a reference to a new AppConfig 
object.
       
    my $config = AppConfig->new();

This will create and return a reference to a new AppConfig object.

In doing so, the AppConfig object also creates an internal reference
to an App::State object in which to store variable state.  All 
arguments passed into the AppConfig constructor are passed directly
to the App::State constructor.  

See L<App::State> for full details of the configuration options available.

Note that any unresolved method calls to AppConfig are automatically 
delegated to the AppConfig::State object.  In practice, it means that
it is possible to treat the AppConfig object as if it were an 
AppConfig::State object:

    # create AppConfig
    my $config = AppConfig->new('foo', 'bar');

    # methods get passed through to internal AppConfig::State
    $config->foo(100);
    $config->set('bar', 200);
    $config->define('baz');
    $config->baz(300);
    

=head2 DEFINING VARIABLES

The C<define()> function is used to pre-declare a variable and specify 
its configuration.

    $config->define("foo");

In the simple example above, a new variable called "foo" is defined.  A 
reference to a hash array may also be passed to specify configuration 
information for the variable:

    $config->define("foo", {
	    DEFAULT   => 99,
	    ALIAS     => 'metavar1',
	});

See L<AppConfig::State) for further details of the configuration options
available when defining variables.

=head2 READING AND MODIFYING VARIABLE VALUES

AppConfig defines two methods to manipulate variable values: 

    set($variable, $value);
    get($variable);

Once defined, variables may be accessed directly as object methods where
the method name is the same as the variable name.  i.e.

    $config->set("verbose", 1);

is equivalent to 

    $config->verbose(1); 

Without parameters, the current value of the variable is returned.  If
a parameter is specified, the variable is set to that value and the 
original value (before modification) is returned.

    $config->age(28);  
    $config->age(29);        # sets 'age' to 29, returns 28

=head2 READING CONFIGURATION FILES

The AppConfig module provides a streamlined interface for reading 
configuration files with the AppConfig::File module.  The file() method
automatically loads the AppConfig::File module and creates an object 
to process the configuration file(s).  Variables stored in the internal
AppConfig::State are automatically updated with values specified in the 
configuration file.  

    $config->file($file);

Multiple files may be passed to file() and should indicate the file name 
or be a reference to an open file handle or glob.

    $config->file($file, $filehandle, \*STDIN, ...);

The configuration file should contain lines of the form:

    variable = value

The separating '=' is optional.

Variables that are simple flags and do not expect an argument (ARGS = 0)
can be specified without any value.  They will be set with the value 1.

Variable values may contain references to other AppConfig variables, 
environment variables and/or users' home directories.  These will be 
expanded depending on the EXPAND value set in the AppConfig::State.  
Three different expansion types may be applied:

    bin = ~/bin          # expand '~' to home dir if EXPAND_UID
    tmp = ~abw/tmp       # as above, but home dir for user 'abw'

    perl = $bin/perl     # expand value of 'bin' variable if EXPAND_VAR
    ripl = $(bin)/ripl   # as above with explicit parens

    home = ${HOME}       # expand HOME environment var if EXPAND_ENV

See L<AppConfig::File> for further details on reading configuration files
and expanding variable values.

=head2 PARSING COMMAND LINE OPTIONS

The args() method is used to parse command line options.  It
automatically loads the AppConfig::Args module and creates an object 
to process the command line arguments.  Variables stored in the internal
AppConfig::State are automatically updated with values specified in the 
arguments:

    $config->args(\@ARGV);

Variables should be prefixed by a '-' or '--'.

    myprog -verbose --debug

Variables that expect an additional argument (ARGS != 0) will be set to 
the value of the argument following it.  If the next argument starts with 
a '-' then a warning will be raised and the value will not be set.

    myprog --verbose -f /tmp/myfile
    
Variables that do not expect a value (ARGS = 0) will be set to 1.

Any arguments remaining at the end of the list that do not start with a
'-' will not be processed.  These arguments will remain in the list when 
args() returns.  Valid arguments and value will be removed from the list.

See L<AppConfig::Args> for further details on parsing command line
arguments.

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

AppConfig::State, AppConfig::File, AppConfig::Args

=cut
