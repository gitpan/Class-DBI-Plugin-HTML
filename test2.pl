#!/usr/bin/perl

use CGI;

=pod

This script produces a working CGI based page that allows for
navigating through result sets from databases from the
Class::DBI::Pager object and generates a form based on the
Class::DBI::AsForm module.

=cut

my $cgi = CGI->new();

print $cgi->header();

use ihelpyou::SEO::CDBI; # <- replace this with your own Class::DBI sub class

# optional
use HTML::Table;
use Data::Dumper;
use strict;

my $pager = Table::User->pager(20, $cgi->param('page') || 1);

# optional
my $html_table = Table::User->html_table(-align=>'center');

# optional, but sets the top row as the column titles in this example.
$html_table->addRow('User Name','First Name','Last Name');

my $table = Table::User->build_table(
                         -pager   => $pager,
                         -columns => [ 'user_name','first_name','last_name' ],
			 -exclude => [ 'created_on' , 'modified_on' ],
			 -table   => $html_table,
			 ranking_report_id => sub {
		             return qq!<a href="show.htm?id=! . shift() . qq!">view</a>!  
                         }, );

			 
my $nav = Table::User->html_table_navigation(
                         -pager        => $pager,
			 -navigation   => 'block',
			 -page_url     => 'render_test.pl',
			 
			 
);
print "'$nav'\n";

Table::User->add_bottom_span($table,$nav);
			 
print $table;

my $user = Table::User->retrieve(1);

#my $form = Table::User->build_form(
my $form = $user->build_form(                         
			 -pager   => $pager,
                         # -columns => [ 'user_name','first_name','last_name' ],
			 -exclude => [ 'user_id' , 'created_on' , 'modified_on' ],
			 -label        => { user_name => 'User Name' },
			 user_name => sub {
		             return shift() . qq! <a href="view.pl">view</a>!  
                         }, );
print $form;

my $params = { user_name => 'trs80', first_name => 'TRS' };
my $ignore = [ 'last_name' ];

print Table::User->fill_in_form(
    scalarref     => \$form,
    fdat          => $params,
    ignore_fields => $ignore);
