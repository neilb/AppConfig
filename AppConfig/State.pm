#============================================================================
#
# AppConfig::State.pm
#
# Perl5 module in which configuration information for an application can
# be stored and manipulated.  AppConfig::State objects maintain knowledge 
# about variables; their identities, options, aliases, targets, callbacks 
# and so on.  This module is used by a number of other AppConfig::* modules.
#
# Written by Andy Wardley <abw@cre.canon.co.uk>
#
# Copyright (C) 1997,1998 Canon Research Centre Europe Ltd.
# All Rights Reserved.
#
#----------------------------------------------------------------------------
#
# TODO
#
# * define() should accept a variable name parameter of the GetOpt::Long
#   form: e.g. "foo|bar|baz=i@" and extract the relevant configuration 
#   information from it.
#
# * Perhaps allow a callback to be installed which is called *instead* of 
#   the get() and set() methods (or rather, is called by them).
#
# * Maybe CMDARG should be in there to specify extra command-line only 
#   options that get added to the AppConfig::GetOpt alias construction, 
#   but not applied in config files, general usage, etc.  The GLOBAL 
#   CMDARG might be specified as a format, e.g. "-%c" where %s = name, 
#   %c = first character, %u - first unique sequence(?).  Will 
#   GetOpt::Long handle --long to -l application automagically?
#
# * ..and an added thought is that CASE sensitivity may be required for the
#   command line (-v vs -V, -r vs -R, for example), but not for parsing 
#   config files where you may wish to treat "Name", "NAME" and "name" alike.
#
#----------------------------------------------------------------------------
#
# $Id: State.pm,v 0.2 1998/10/08 19:54:57 abw Exp abw $
#
#============================================================================

package AppConfig::State;

require 5.004;

use strict;
use vars qw( $VERSION $AUTOLOAD $DEBUG );

$VERSION = sprintf("%d.%02d", q$Revision: 0.2 $ =~ /(\d+)\.(\d+)/);
$DEBUG   = 0;

# internal per-variable hashes that AUTOLOAD should provide access to
my %METHVARS;
   @METHVARS{ qw( EXPAND ARGS ) } = ();

# internal values that AUTOLOAD should provide access to
my %METHFLAGS;
   @METHFLAGS{ qw( PEDANTIC ) } = ();

# variable attributes that may be specified in GLOBAL;
my @GLOBAL_OK = qw( DEFAULT EXPAND VALIDATE ACTION ARGS ARGCOUNT );



#========================================================================
#                      -----  PUBLIC METHODS -----
#========================================================================

#========================================================================
#
# new(\%config, @vars)
#
# Module constructor.  A reference to a hash array containing 
# configuration options may be passed as the first parameter.  This is 
# passed off to _configure() for processing.  See _configure() for 
# information about configurarion options.  The remaining parameters
# may be variable definitions and are passed en masse to define() for
# processing.
#
# Returns a reference to a newly created AppConfig::State object.
#
#========================================================================

sub new {
    my $class = shift;
    
    my $self = {
	# internal hash arrays to store variable specification information
	VARIABLE   => { },     # variable values
	DEFAULT    => { },     # default values
	ALIAS      => { },     # known aliases  ALIAS => VARIABLE
	ALIASES    => { },     # reverse alias lookup VARIABLE => ALIASES
	ARGS       => { },     # variable args (for AppConfig::GetOpt, etc)
	EXPAND     => { },     # variable expansion (for AppConfig::File)
    #   CMDARG     => { },     # cmd line argument pattern (deprecated)
	VALIDATE   => { },     # validation regexen or functions
	ACTION     => { },     # callback functions for when variable is set
	GLOBAL     => { },     # default global settings for new variables

	# other internal data
    #	ENDOFARGS  => '--',    # marks end of cmd line args (deprecated)
	CREATE     => 0,       # auto-create variables when set
	CASE       => 0,       # case sensitivity flag (1 = sensitive)
	PEDANTIC   => 0,       # return immediately on parse warnings
	EHANDLER   => undef,   # error handler (let's hope we don't need it!)
	ERROR      => '',      # error message
    };

    bless $self, $class;
	
    # configure if first param is a config hash ref
    $self->_configure(shift)
	if ref($_[0]) eq 'HASH';

    # call define(@_) to handle any variables definitions
    $self->define(@_)
	if @_;

    return $self;
}



#========================================================================
#
# define($variable, \%cfg, [$variable, \%cfg, ...])
#
# Defines one or more variables.  The first parameter specifies the 
# variable name.  The following parameter may reference a hash of 
# configuration options for the variable.  Further variables and 
# configuration hashes may follow and are processed in turn.  If the 
# parameter immediately following a variable name isn't a hash reference 
# then it is ignored and the variable is defined without a specific 
# configuration, although any default parameters as specified in the 
# GLOBAL option will apply.
#
# A warning is issued (via _error()) if an invalid option is specified.
#
#========================================================================

sub define {
    my $self = shift;
    my ($var, $opt, $cfg);

    while (@_) {
	$var = shift;
	$cfg = ref($_[0]) eq 'HASH' ? shift : undef;

    	# variable name gets folded to lower unless CASE sensitive
	$var = lc $var unless $self->{ CASE };

	# activate $variable (so it does 'exist()') 
	$self->{ VARIABLE }->{ $var } = undef;

	# use defaults from globally set values
	foreach (keys %{ $self->{ GLOBAL } }) {
    	    $self->{ uc $_ }->{ $var } = $self->{ GLOBAL }->{ $_ };
	}

	# examine each variable configuration parameter
	foreach $opt (keys %$cfg) {

	    # DEFAULT, VALIDATE, EXPAND and ARGS are stored as they are;
	    $opt =~ /^DEFAULT|VALIDATE|EXPAND|ARG(S|COUNT)$/i && do {
		# ARGCOUNT is an alias for ARGS for backwards compatibility
		if (uc $opt eq 'ARGCOUNT') {
		    $self->{ ARGS }->{ $var } = $cfg->{ $opt };
		}
		else {
		    $self->{ uc $opt }->{ $var } = $cfg->{ $opt };
		}
		next;
	    };

	    # CMDARG has been deprecated
	    $opt =~ /^CMDARG$/i && do {
		$self->_error("CMDARG has been deprecated.  "
			. "Please use an ALIAS if required.");
		next;
	    };

	    # ACTION should be a code ref
	    $opt =~ /^ACTION$/i && do {
		unless (ref($cfg->{ $opt }) eq 'CODE') {
		    $self->_error("'$opt' value is not a code reference");
		    next;
		};

		# store code ref, forcing keyword to upper case
		$self->{ ACTION }->{ $var } = $cfg->{ $opt };

		next;
	    };

	    # ALIAS creates alias links to the variable name
	    $opt =~ /^ALIAS$/i && do {
		my $alias = $cfg->{ $opt };

		# coerce $alias to an array if not already so
		$alias = [ split(/\|/, $alias) ]
		    unless ref($alias) eq 'ARRAY';

		# store list of aliases...
		$self->{ ALIASES }->{ $var } = $alias;

		# ...and create ALIAS => VARIABLE lookup hash entries
		foreach my $a (@$alias) {
		    $a = lc $a if $self->{ CASE };
		    $self->{ ALIAS }->{ $a } = $var;
		}

		next;
	    };

	    # default 
	    $self->_error("$opt is not a valid configuration item");
	}

    	# set variable to default value
	$self->_default($var);

	# DEBUG: dump new variable definition
	if ($DEBUG) {
	    print STDERR "Variable defined:\n";
    	    $self->_dump_var($var);
	}
    }
}




#========================================================================
#
# get($variable)
#
# Returns the value of the variable specified, $variable.  Returns undef
# if the variable does not exists or is undefined and send a warning
# message to the _error() function.
#
#========================================================================

sub get {
    my $self     = shift;
    my $variable = shift;


    # _varname returns variable name after aliasing and case conversion
    $variable = $self->_varname($variable);

    # check the variable has been defined
    unless (exists($self->{ VARIABLE }->{ $variable })) {
	$self->_error("$variable: no such variable");
	return undef;
    }

    # DEBUG
    print STDERR "$self->get($variable) => ", 
	   defined $self->{ VARIABLE }->{ $variable }
		  ? $self->{ VARIABLE }->{ $variable }
		  : "<undef>",
	  "\n"
	if $DEBUG;

    # return variable value
    $self->{ VARIABLE }->{ $variable };
}



#========================================================================
#
# set($variable, $value)
#
# Assigns the value, $value, to the variable specified.
#
# Returns 1 if the variable is successfully updated or 0 if the variable 
# does not exist.  If an ACTION sub-routine exists for the variable, it 
# will be executed and its return value passed back.
#
#========================================================================

sub set {
    my $self     = shift;
    my $variable = shift;
    my $value    = shift;
    

    # _varname returns variable name after aliasing and case conversion
    $variable = $self->_varname($variable);

    # check the variable exists
    unless (exists($self->{ VARIABLE }->{ $variable })) {

	# auto-create variable if CREATE is 1 or a pattern matching 
	# the variable name (real name, not an alias)
	if (my $create = $self->{ CREATE }) {
	    $self->define($variable)
		if ($create eq '1' || $variable =~ /$create/);
	}
	else {
	    $self->_error("$variable: no such variable");
	    return 0;
	}
    }

    # call the validate($variable, $value) method to perform any validation
    unless ($self->_validate($variable, $value)) {
	$self->_error("$variable: invalid value: $value");
	return 0;
    }

    # DEBUG
    print STDERR "$self->set($variable, ", 
	   defined $value
		  ? $value
		  : "<undef>",
	  ")\n"
	if $DEBUG;

    # cast it in stone...
    $self->{ VARIABLE }->{ $variable } = $value;

    # ...and call any ACTION function bound to this variable
    return &{ $self->{ ACTION }->{ $variable } }($self, $variable, $value)
    	if (exists($self->{ ACTION }->{ $variable }));

    # ...or just return 1 (ok)
    return 1;
}




    
#========================================================================
#
# AUTOLOAD
#
# Autoload function called whenever an unresolved object method is 
# called.  If the method name relates to a defined VARIABLE, we patch
# in $self->get() and $self->set() to magically update the varaiable
# (if a parameter is supplied) and return the previous value.
#
# Thus the function can be used in the folowing ways:
#    $state->variable(123);     # set a new value
#    $foo = $state->variable(); # get the current value
#
# Returns the current value of the variable, taken before any new value
# is set.  Prints a warning if the variable isn't defined (i.e. doesn't
# exist rather than exists with an undef value) and returns undef.
#
#========================================================================

sub AUTOLOAD {
    my $self = shift;
    my ($variable, $attrib);


    # splat the leading package name
    ($variable = $AUTOLOAD) =~ s/.*:://;

    # ignore destructor
    $variable eq 'DESTROY' && return;


    # per-variable attributes and internal flags listed as keys in 
    # %METHFLAGS and %METHVARS respectively can be accessed by a 
    # method matching the attribute or flag name in lower case with 
    # a leading underscore_
    if (($attrib = $variable) =~ s/_//g) {
	$attrib = uc $attrib;
	
	if (exists $METHFLAGS{ $attrib }) {
	    return $self->{ $attrib };
	}

	if (exists $METHVARS{ $attrib }) {
	    # next parameter should be variable name
	    $variable = shift;
	    $variable = $self->_varname($variable);

	    # check we've got a valid variable
	    $self->_error("$variable: no such variable or method"), 
		    return undef
		unless exists($self->{ VARIABLE }->{ $variable });

	    # return attribute
	    return $self->{ $attrib }->{ $variable };
	}
    }

    # set a new value if a parameter was supplied or return the old one
    return defined($_[0])
           ? $self->set($variable, shift)
           : $self->get($variable);
}



#========================================================================
#                      -----  PRIVATE METHODS -----
#========================================================================

#========================================================================
#
# _configure(\%cfg)
#
# Sets the various configuration options using the values passed in the
# hash array referenced by $cfg.
#
#========================================================================

sub _configure {
    my $self = shift;
    my $cfg  = shift || return;

    # construct a regex to match values which are ok to be found in GLOBAL
    my $global_ok = join('|', @GLOBAL_OK);

    foreach my $opt (keys %$cfg) {

	# GLOBAL must be a hash ref
	$opt =~ /^GLOBALS?$/i && do {
	    unless (ref($cfg->{ $opt }) eq 'HASH') {
		$self->_error("\U$opt\E parameter is not a hash ref");
                next;
            }

            # we check each option is ok to be in GLOBAL, but we don't do 
	    # any error checking on the values they contain (but should?).
            foreach my $global ( keys %{ $cfg->{ $opt } } )  {

		# ARGCOUNT is backwards compatibility for ARGS
		if (uc $global eq 'ARGCOUNT') {
		    $cfg->{ $opt }->{ ARGS } = $cfg->{ $opt }->{ $global };
		    delete $cfg->{ $opt }->{ $global };
		    next;
		}

		# continue if the attribute is ok to be GLOBAL 
                next if ($global =~ /(^$global_ok$)/io);

                $self->_error( "\U$global\E parameter cannot be GLOBAL");
            }
            $self->{ GLOBAL } = $cfg->{ $opt };
            next;
        };

	
	# CASE, CREATE and PEDANTIC are stored as they are
	$opt =~ /^CASE|CREATE|PEDANTIC$/i && do {
	    $self->{ uc $opt } = $cfg->{ $opt };
	    next;
	};

	# ERROR triggers $self->_ehandler()
	$opt =~ /^ERROR$/i && do {
	    $self->_ehandler($cfg->{ $opt });
	    next;
	};

	# DEBUG triggers $self->_debug()
	$opt =~ /^DEBUG$/i && do {
	    $self->_debug($cfg->{ $opt });
	    next;
	};

	# warn about invalid options
	$self->_error("\U$opt\E is not a valid configuration option");
    }
}



#========================================================================
#
# _varname($variable)
#
# Variable names are treated case-sensitively or insensitively, depending 
# on the value of $self->{ CASE }.  When case-insensitive ($self->{ CASE } 
# != 0), all variable names are converted to lower case.  Variable values 
# are not converted.  This function simply converts the parameter 
# (variable) to lower case if $self->{ CASE } isn't set.  _varname() also 
# expands a variable alias to the name of the target variable.  
#
# The (possibly modified) variable name is returned.
#
#========================================================================

sub _varname {
    my $self = shift;
    my $variable = shift;

    # convert to lower case if case insensitive
    $variable = $self->{ CASE } ? $variable : lc $variable;

    # get the actual name if this is an alias
    $variable = $self->{ ALIAS }->{ $variable }
	if (exists($self->{ ALIAS }->{ $variable }));
   
    # return the variable name
    $variable;
}



#========================================================================
#
# _default($variable)
#
# Sets the variable specified to the default value or undef if it doesn't
# have a default.  The default value is returned.
#
#========================================================================

sub _default {
    my $self     = shift;
    my $variable = shift;

    # _varname returns variable name after aliasing and case conversion
    $variable = $self->_varname($variable);

    # check the variable exists
    if (exists($self->{ VARIABLE }->{ $variable })) {
	return $self->{ VARIABLE }->{ $variable } 
		    = $self->{ DEFAULT }->{ $variable };
    }
    else {
	$self->_error("$variable: no such variable");
	return 0;
    }
}



#========================================================================
#
# _exists($variable)
#
# Returns 1 if the variable specified exists or 0 if not.
#
#========================================================================

sub _exists {
    my $self     = shift;
    my $variable = shift;


    # _varname returns variable name after aliasing and case conversion
    $variable = $self->_varname($variable);

    # check the variable has been defined
    return exists($self->{ VARIABLE }->{ $variable });
}



#========================================================================
#
# _validate($variable, $value)
#
# Uses any validation rules or code defined for the variable to test if
# the specified value is acceptable.
#
# Returns 1 if the value passed validation checks, 0 if not.
#
#========================================================================

sub _validate {
    my $self     = shift;
    my $variable = shift;
    my $value    = shift;
    my $validator;


    # _varname returns variable name after aliasing and case conversion
    $variable = $self->_varname($variable);

    # return OK unless there is a validation function
    return 1 unless defined($validator = $self->{ VALIDATE }->{ $variable });

    #
    # the validation performed is based on the validator type;
    #
    #   CODE ref: code executed, returning 1 (ok) or 0 (failed)
    #   SCALAR  : a regex which should match the value
    #

    # CODE ref
    ref($validator) eq 'CODE' && do {
    	# run the validation function and return the result
       	return &$validator($variable, $value);
    };

    # non-ref (i.e. scalar)
    ref($validator) || do {
	# not a ref - assume it's a regex
	return $value =~ /$validator/;
    };
    
    # validation failed
    return 0;
}



#========================================================================
#
# _error($format, @params)
#
# Checks for the existence of a user defined error handling routine and
# if defined, passes all variable straight through to that.  The routine
# is expected to handle a string format and optional parameters as per
# printf(3C).  If no error handler is defined, the message is formatted
# and passed to warn() which prints it to STDERR.
#
#========================================================================

sub _error {
    my $self   = shift;
    my $format = shift;

    # user defined error handler?
    if (ref($self->{ EHANDLER }) eq 'CODE') {
	&{ $self->{ EHANDLER } }($format, @_);
    }
    else {
	warn(sprintf("$format\n", @_));
    }
}



#========================================================================
#
# _ehandler($handler)
#
# Allows a new error handler to be installed.  The current value of 
# the error handler is returned.
#
# This is something of a kludge to allow other AppConfig::* modules to 
# install their own error handlers to format error messages appropriately.
# For example, AppConfig::File appends a message of the form 
# "at $file line $line" to each error message generated while parsing 
# configuration files.  The previous handler is returned (and presumably
# stored by the caller) to allow new error handlers to chain control back
# to any user-defined handler, and also restore the original handler when 
# done.
#
# This method is considered private, although other AppConfig::* modules
# (friends) are expected to use it.
#
#========================================================================

sub _ehandler {
    my $self    = shift;
    my $handler = shift;

    # save previous value
    my $previous = $self->{ EHANDLER };

    # update internal reference if a new handler vas provide
    if (defined $handler) {
	# check this is a code reference
	if (ref($handler) eq 'CODE') {
	    $self->{ EHANDLER } = $handler;

	    # DEBUG
	    print STDERR "installed new ERROR handler: $handler\n" if $DEBUG;
	}
	else {
	    $self->_error("ERROR handler parameter is not a code ref");
	}
    }

    return $previous;
}



#========================================================================
#
# _debug($debug)
#
# Sets the package debugging variable, $AppConfig::State::DEBUG depending 
# on the value of the $debug parameter.  1 turns debugging on, 0 turns 
# debugging off.
#
# May be called as an object method, $state->_debug(1), or as a package
# function, AppConfig::State::_debug(1).
#
# Returns the previous value of $DEBUG, before any new value was applied.
#
#========================================================================

sub _debug {
    # object reference may not be present if called as a package function
    my $self   = shift if ref($_[0]);
    my $newval = shift;

    # save previous value
    my $oldval = $DEBUG;

    # update $DEBUG if a new value was provided
    $DEBUG = $newval if defined $newval;

    # return previous value
    $oldval;
}



#========================================================================
#
# _dump_var($var)
#
# Displays the content of the specified variable, $var.
#
#========================================================================

sub _dump_var {
    my $self   = shift;
    my $var    = shift;


    return unless defined $var;


    # $var may be an alias, so we resolve the real variable name
    my $real = $self->_varname($var);
    if ($var eq $real) {
    	print STDERR "$var\n";
    }
    else {
    	print STDERR "$real  ('$var' is an alias)\n";
	$var = $real;
    }

    # for some bizarre reason, the variable VALUE is stored in VARIABLE
    # (it made sense at some point in time)
    printf STDERR "    VALUE        => %s\n", 
		defined($self->{ VARIABLE }->{ $var }) 
		    ? $self->{ VARIABLE }->{ $var } 
		    : "<undef>";

    # the rest of the values can be read straight out of their hashes
    foreach my $param (qw( DEFAULT ARGS VALIDATE ACTION EXPAND )) {
	printf STDERR "    %-12s => %s\n", $param, 
		defined($self->{ $param }->{ $var }) 
		    ? $self->{ $param }->{ $var } 
		    : "<undef>";
    }

    # summarise all known aliases for this variable
    print STDERR "    ALIASES      => ", 
	    join(", ", @{ $self->{ ALIASES }->{ $var } }), "\n"
	if defined $self->{ ALIASES }->{ $var };
} 



#========================================================================
#
# _dump()
#
# Dumps the contents of the Config object and all stored variables.  
#
#========================================================================

sub _dump {
    my $self = shift;
    my $var;

    print STDERR "=" x 71, "\n";
    print STDERR 
	"Status of AppConfig::State (version $VERSION) object:\n\t$self\n";

    
    print STDERR "- " x 36, "\nINTERNAL STATE:\n";
    foreach (qw( CREATE CASE PEDANTIC EHANDLER ERROR )) {
	printf STDERR "    %-12s => %s\n", $_, 
		defined($self->{ $_ }) ? $self->{ $_ } : "<undef>";
    }	    

    print STDERR "- " x 36, "\nVARIABLES:\n";
    foreach $var (keys %{ $self->{ VARIABLE } }) {
	$self->_dump_var($var);
    }

    print STDERR "- " x 36, "\n", "ALIASES:\n";
    foreach $var (keys %{ $self->{ ALIAS } }) {
	printf("    %-12s => %s\n", $var, $self->{ ALIAS }->{ $var });
    }
    print STDERR "=" x 72, "\n";
} 



1;

__END__

=head1 NAME

AppConfig::State - Perl5 module for maintaining the state of an application
configuration.

=head1 SYNOPSIS

    use AppConfig::State;

    my $state = AppConfig::State->new(\%cfg);

    $state->define("foo");            # very simple variable definition
    $state->define("bar", \%varcfg);  # variable specific configuration

    $state->set("foo", 123);          # trivial set/get examples
    $state->get("foo");      
    
    $state->foo();                    # shortcut variable access 
    $state->foo(456);                 # shortcut variable update 

=head1 OVERVIEW

AppConfig::State is a Perl5 module to handle global configuration variables
for perl programs.  It maintains the state of any number of variables,
handling default values, aliasing, validation, update callbacks and 
option arguments for use by other AppConfig::* modules.  

AppConfig::State is distributed as part of the AppConfig bundle.

=head1 DESCRIPTION

=head2 USING THE AppConfig::State MODULE

To import and use the AppConfig::State module the following line should 
appear in your Perl script:

     use AppConfig::State;

The AppConfig::State module is used automatically if you use the
AppConfig module.
      
AppConfig::State is implemented using object-oriented methods.  A 
new AppConfig::State object is created and initialised using the 
new() method.  This returns a reference to a new AppConfig::State 
object.
       
    my $state = AppConfig::State->new();

This will create a reference to a new AppConfig::State with all 
configuration options set to their default values.  You can initialise 
the object by passing a reference to a hash array containing 
configuration options:

    $state = AppConfig::State->new( {
	CASE      => 1,
	ERROR     => \&my_error,
    } );

The following configuration options may be specified.  

=over 4

=item CASE

Determines if the variable names are treated case sensitively.  Any non-zero
value makes case significant when naming variables.  By default, CASE is set
to 0 and thus "Variable", "VARIABLE" and "VaRiAbLe" are all treated as 
"variable".

=item CREATE

By default, CREATE is turned off meaning that all variables accessed via
set() (which includes access via shortcut such as 
C<$state->variable($value)> which delegates to set()) must previously 
have been defined via define().  When CREATE is set to 1, calling 
set($variable, $value) on a variable that doesn't exist will cause it 
to be created automatically.

When CREATE is set to any other non-zero value, it is assumed to be a
regular expression pattern.  If the variable name matches the regex, the
variable is created.  This can be used to specify configuration file 
blocks in which variables should be created, for example:

    $state = AppConfig::State->new( {
	CREATE => '^define_',
    } );

In a config file:

    [define]
    name = fred           # define_name gets created automatically

Note that a regex pattern specified in CREATE is applied to the real 
variable name rather than any alias by which the variables may be 
accessed.  

=item PEDANTIC

The PEDANTIC option determines what action the configuration file 
(AppConfig::File) or argument parser (AppConfig::Args) should take 
on encountering a warning condition (typically caused when trying to set an
undeclared variable).  If PEDANTIC is set to any true value, the parsing
methods will immediately return a value of 0 on encountering such a
condition.  If PEDANTIC is not set, the method will continue to parse the
remainder of the current file(s) or arguments, returning 0 when complete.

If no warnings or errors are encountered, the method returns 1.

In the case of a system error (e.g. unable to open a file), the method
returns undef immediately, regardless of the PEDANTIC option.

=item ERROR

Specifies a user-defined error handling routine.  When the handler is 
called, a format string is passed as the first parameter, followed by 
any additional values, as per printf(3C).

=item DEBUG

Turns debugging on or off when set to 1 or 0 accordingly.  Debugging may 
also be activated by calling _debug() as an object method 
(C<$state->_debug(1)>) or as a package function 
(C<AppConfig::State::_debug(1)>), passing in a true/false value to 
set the debugging state accordingly.  The package variable 
$AppConfig::State::DEBUG can also be set directly.  

The _debug() method returns the current debug value.  If a new value 
is passed in, the internal value is updated, but the previous value is 
returned.

Note that any AppConfig::File or App::Config::Args objects that are 
instantiated with a reference to an App::State will inherit the 
DEBUG (and also PEDANTIC) values of the state at that time.  Subsequent
changes to the AppConfig::State debug value will not affect them.

=item GLOBAL 

The GLOBAL option allows default values to be set for the DEFAULT, ARGS, 
EXPAND, VALIDATE and ACTION options for any subsequently defined variables.

    $state = AppConfig::State->new({
	GLOBAL => {
	    DEFAULT => '<undef>',     # default value for new vars
	    ARGS    => 1,             # vars expect an argument
	    ACTION  => \&my_set_var,  # callback when vars get set
	}
    });

Any attributes specified explicitly when a variable is defined will
override any GLOBAL values.

L<DEFINING VARIABLES> below describes these options in detail.

=back

=head2 DEFINING VARIABLES

The C<define()> function is used to pre-declare a variable and specify 
its configuration.

    $state->define("foo");

In the simple example above, a new variable called "foo" is defined.  A 
reference to a hash array may also be passed to specify configuration 
information for the variable:

    $state->define("foo", {
	    DEFAULT   => 99,
	    ALIAS     => 'metavar1',
	});

Any variable-wide GLOBAL values passed to the new() constructor in the 
configuration hash will also be applied.  Values explicitly specified 
in a variable's define() configuration will override the respective GLOBAL 
values.

The following configuration options may be specified

=over 4

=item DEFAULT

The DEFAULT value is used to initialise the variable.  

    $state->define("drink", {
	    DEFAULT => 'coffee',
	});

    print $state->drink();        # prints "coffee"

=item ALIAS

The ALIAS option allows a number of alternative names to be specified for 
this variable.  A single alias should be specified as a string.  Multiple 
aliases can be specified as a reference to an array or as a string of names
separated by '|'.  e.g.:

    $state->define("name", {
	    ALIAS  => 'person',
	});
or
    $state->define("name", {
	    ALIAS => [ 'person', 'user', 'uid' ],
	});
or
    $state->define("name", {
	    ALIAS => 'person|user|uid',
	});

    $state->user('abw');     # equivalent to $state->name('abw');

=item ARGS

The ARGS option specifies an argument pattern for command line
processing.  Currently a value of 1 will indicate that the variable
expects a value parameter following it in the argument list.  An error
will be raised if this is not the case.  In a future version of
AppConfig::State this value will also be used to specify more complex
argument options in the style of Getopt::Long (to which it will
delegate).

The configuration file processing module, AppConfig::File also examines
this variable and raises a warning if an argument was expected and 
no value was provided.  Variables that don't have any ARGS will be set
to the value 1 if no other value is provided.

ARGCOUNT is an alias for ARGS to provide backward compatibility with
the App::Config module, the predecessor to AppConfig::*.

=item EXPAND 

The EXPAND option specifies how the AppConfig::File processor should 
expand embedded variables in the configuration file values it reads.
By default, EXPAND is turned off (EXPAND_NONE) and no expansion is made.  

The EXPAND_* constants can be imported from the AppConfig::Const module:

    use AppConfig::State ':expand';

    $state->define('foo', { EXPAND => EXPAND_VAR });

or can be accessed directly from the AppConfig::Const package:

    use AppConfig::State;

    $state->define('foo', { EXPAND => AppConfig::Const::EXPAND_VAR });

The following values for EXPAND may be specified.  Multiple values should
be combined with vertical bars , '|', e.g. c<EXPAND_UID | EXPAND_VAR).

=over 4

=item EXPAND_NONE

Indicates that no variable expansion should be attempted.

=item EXPAND_VAR

Inidicates that variables embedded as $var or $(var) should be expanded
to the values of the relevant AppConfig::State variables.

=item EXPAND_UID 

Indicates that '~' or '~uid' patterns in the string should be 
expanded to the current users ($<), or specified user's home directory.

=item EXPAND_ENV

Inidicates that variables embedded as ${var} should be expanded to the 
value of the relevant environment variable.

=item EXPAND_ALL

Equivalent to C<EXPAND_VARS | EXPAND_UIDS | EXPAND_ENVS).

=item EXPAND_WARN

Indicates that embedded variables that are not defined should raise a
warning.  If PEDANTIC is set, this will cause the read() method to return 0
immediately.

=back

=item VALIDATE

Each variable may have a sub-routine or regular expression defined which 
is used to validate the intended value for a variable before it is set.

If VALIDATE is defined as a regular expression, it is applied to the
value and deemed valid if the pattern matches.  In this case, the
variable is then set to the new value.  A warning message is generated
if the pattern match fails.

VALIDATE may also be defined as a reference to a sub-routine which takes
as its arguments the name of the variable and its intended value.  The 
sub-routine should return 1 or 0 to indicate that the value is valid
or invalid, respectively.  An invalid value will cause a warning error
message to be generated.

If the GLOBAL VALIDATE variable is set (see GLOBAL in L<DESCRIPTION> 
above) then this value will be used as the default VALIDATE for each 
variable unless otherwise specified.

    $state->define("age", {
    	    VALIDATE => '\d+',
	});

    $state->define("pin", {
	    VALIDATE => \&check_pin,
	});

=item ACTION

The ACTION option allows a sub-routine to be bound to a variable as a
callback that is executed whenever the variable is set.  The ACTION is
passed a reference to the AppConfig::State object, the name of the
variable and the value of the variable.

The ACTION routine may be used, for example, to post-process variable
data, update the value of some other dependant variable, generate a
warning message, etc.

Example:

    $state->define("foo", { ACTION => \&my_notify });

    sub my_notify {
	my $state = shift;
	my $var   = shift;
	my $val   = shift;

	print "$variable set to $value";
    }

    $state->foo(42);        # prints "foo set to 42"

Be aware that calling C<$state-E<gt>set()> to update the same variable
from within the ACTION function will cause a recursive loop as the
ACTION function is repeatedly called.  This is probably a bug, certainly
a limitation.

=item 

=back

=head2 READING AND MODIFYING VARIABLE VALUES

AppConfig::State defines two methods to manipulate variable values: 

    set($variable, $value);
    get($variable);

Both functions take the variable name as the first parameter and
C<set()> takes an additional parameter which is the new value for the
variable.  C<set()> returns 1 or 0 to indicate successful or
unsuccessful update of the variable value.  If there is an ACTION
routine associated with the named variable, the value returned will be
passed back from C<set()>.  The C<get()> function returns the current
value of the variable.

Once defined, variables may be accessed directly as object methods where
the method name is the same as the variable name.  i.e.

    $state->set("verbose", 1);

is equivalent to 

    $state->verbose(1); 

Without parameters, the current value of the variable is returned.  If
a parameter is specified, the variable is set to that value and the 
original value (before modification) is returned.

    $state->age(28);  
    $state->age(29);        # sets 'age' to 29, returns 28

=head2 INTERNAL METHODS

The interal (private) methods of the AppConfig::State class are listed 
below.

They aren't intended for regular use and potential users should consider
the fact that nothing about the internal implementation is guaranteed to
remain the same.  Having said that, the AppConfig::State class is
intended to co-exist and work with a number of other modules and these
are considered "friend" classes.  These methods are provided, in part,
as services to them.  With this acknowledged co-operation in mind, it is
safe to assume some stability in this core interface.

The _varname() method can be used to determine the real name of a variable 
from an alias:

    $varname->_varname($alias);

Note that all methods that take a variable name, including those listed
below, can accept an alias and automatically resolve it to the correct 
variable name.  There is no need to call _varname() explicitly to do 
alias expansion.  The _varname() method will fold all variables names
to lower case unless CASE sensititvity is set.

The _exists() method can be used to check if a variable has been
defined:

    $state->_exists($varname);

The _default() method can be used to reset a variable to its default value:

    $state->_default($varname);

The _expand() method can be used to determine the EXPAND value for a 
variable:

    print "$varname EXPAND: ", $state->_expand($varname), "\n";

The _args() method returns the value of the ARGS (also known as ARGCOUNT)
attribute for a variable:

    print "$varname ARGS: ", $state->_args($varname), "\n";

The _validate() method can be used to determine if a new value for a variable
meets any validation criteria specified for it.  The variable name and 
intended value should be passed in.  The methods returns a true/false value
depending on whether or not the validation succeeded:

    print "OK\n" if $state->_validate($varname, $value);

The _pedantic() method can be called to determine the current value of the
PEDANTIC option.

    print "pedantic mode is ", $state->_pedantic() ? "on" ; "off", "\n";

The _debug() method can be used to turn debugging on or off (pass 1 or 0
as a parameter).  It can also be used to check the debug state,
returning the current internal value of $AppConfig::State::DEBUG.  If a
new debug value is provided, the dbug state is updated and the previous
state is returned.

    $state->_debug(1);               # debug on, returns previous value

The _dump_var($varname) and _dump() methods may also be called for
debugging purposes.  

    $state->_dump_var($varname);    # show variable state
    $state->_dump();                # show internal state and all vars

=head1 AUTHOR

Andy Wardley, C<E<lt>abw@cre.canon.co.ukE<gt>>

Web Technology Group, Canon Research Centre Europe Ltd.

=head1 REVISION

$Revision: 0.2 $

=head1 COPYRIGHT

Copyright (C) 1998 Canon Research Centre Europe Ltd.  
All Rights Reserved.

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.

=head1 SEE ALSO

AppConfig, AppConfig::File, AppConfig::Args, AppConfig::Const

=cut
