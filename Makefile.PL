use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	     => 'AppConfig',
    'VERSION_FROM'   => 'AppConfig.pm', # finds $VERSION
    'PMLIBDIRS'      => [ 'AppConfig' ],
    'MAN3PODS'       => { 
	# We must explicitly name Config.pm as a manifyable file because 
	# MakeMaker ignores files that match  /(config|setup).*\.pm/i;
	'AppConfig.pm'  => '$(INST_MAN3DIR)/$(NAME).$(MAN3EXT)' 
    },
    'dist'           => { 
	'COMPRESS'   => 'gzip', 
	'SUFFIX'     => 'gz' 
    },
);
