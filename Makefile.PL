use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	     => 'AppConfig',
    'VERSION_FROM'   => 'lib/AppConfig.pm', # finds $VERSION
    'PMLIBDIRS'      => [ 'lib' ],
    'PREREQ_PM'    => { 
	'Test::More'=> 0,
    },

    'MAN3PODS'       => { 
	# We must explicitly name AppConfig.pm et al as manifyable files.
	# MakeMaker ignores files that match  /(config|setup).*\.pm/i;
	'lib/AppConfig.pm'        
		=> '$(INST_MAN3DIR)/AppConfig.$(MAN3EXT)',
	'lib/AppConfig/Args.pm'   
		=> '$(INST_MAN3DIR)/AppConfig::Args.$(MAN3EXT)',
	'lib/AppConfig/CGI.pm'    
		=> '$(INST_MAN3DIR)/AppConfig::CGI.$(MAN3EXT)',
	'lib/AppConfig/File.pm'   
		=> '$(INST_MAN3DIR)/AppConfig::File.$(MAN3EXT)',
	'lib/AppConfig/Getopt.pm' 
		=> '$(INST_MAN3DIR)/AppConfig::Getopt.$(MAN3EXT)',
	'lib/AppConfig/State.pm'  
		=> '$(INST_MAN3DIR)/AppConfig::State.$(MAN3EXT)',
	'lib/AppConfig/Sys.pm'    
		=> '$(INST_MAN3DIR)/AppConfig::Sys.$(MAN3EXT)',
    },
    'dist'           => { 
	'COMPRESS'   => 'gzip', 
	'SUFFIX'     => 'gz',
	'PREOP'      => 'cp docs/header README; \
	                 pod2text docs/README.pod >> README',
    },
);
    
