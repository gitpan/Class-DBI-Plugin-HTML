use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Class::DBI::Plugin::HTML',
    'VERSION_FROM'	=> 'HTML.pm', # finds $VERSION
    'PREREQ_PM'		=> {  
                             Class::DBI::Pager => ">1",
                             Class::DBI::AsForm     => .05,
                             Class::DBI        => .94,
                             HTML::Table       => ">2",
                             HTML::FillInForm  => 1,
                             Class::DBI::Plugin => .03,
                             Class::DBI::Plugin::RetrieveAll => 1,
                             Class::DBI::AbstractSearch => .04,
     
                            }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'HTML.pm', # retrieve abstract from module
       AUTHOR     => 'Aaron Johnson <solution@gina.net>') : ()),
);
