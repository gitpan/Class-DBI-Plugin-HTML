package Class::DBI::Plugin::HTML;

use base qw( Class::DBI::Plugin);

our $VERSION = 0.8;
use HTML::Table;
use HTML::FillInForm;
use CGI qw/:form/;
use Class::DBI::AsForm;
use Data::Dumper;
use URI::Escape;
use strict;

sub html : Plugged {
    my ( $class, %args ) = @_;

    my $self = bless {
    }, $class;
    
    $self;
}

our $debug = 0;

=head1 NAME

Class::DBI::Plugin::HTML - Generate HTML Tables and Forms in conjunction with Class::DBI

=head1 SYNOPSIS

 # Inside of your sub-class of Class::DBI add these lines:
 use Class::DBI::Plugin::HTML;
 use Class::DBI::Pager;
 use Class::DBI::AbstractSearch;
 use Class::DBI::Plugin::AbstractCount;
 use Class::DBI::Plugin::RetrieveAll;
   
 .....
   
 # Inside your script you will be able to use this modules
 # methods on your table class or object as needed.

 use URI::Escape;
 use CGI;
 
 my $cgi = CGI->new();
 
 my $pager = Baseball::Master->pager(20, $cgi->param('page') || 1);

 my $cdbi_plugin_html = Baseball::Master->html();
 
 my $html_table = $cdbi_plugin_html->html_table(-align=>'center');
 
 $cdbi_plugin_html->data_table->addRow('Last Name','First Name','Bats' , 'Throws' ,
                    'Height (ft)','(inches)',
                    'Weight','Birth Year' );
 
 my %params;

 map { $params{$_} = 
        uri_unescape($cgi->param("$_"))
    } $cgi->param();

 $cdbi_plugin_html->params( \%params );    

 $cdbi_plugin_html->search_ref( 
      -like_column_map  => { email => 'sam%' }
 );
 
 $cdbi_plugin_html->url_query(
      -exclude_from_url => [ 'page' ],
 );

    # set the page name (script) 
    $cdbi_plugin_html->page_name('cdbitest.pl');
    
    # indicate which columns to display
    $cdbi_plugin_html->display_columns(     [ 'lastname','firstname',
                  'bats'    ,'throws',
                  'ht_ft'   ,'ht_in',
                  'wt'      ,'birthyear' ]
 );

    # indicate which columns to exclude, inverse of display above
    $cdbi_plugin_html->exclude_columns();
    
    # indicate the base class to work with, this is optional,
    # if you should create you object via a call to
    # Class::DBI::Plugin::HTML vs. a Class::DBI sub class
    # this assures the correct sub class is used for data collection
    $cdbi_plugin_html->cdbi_class( 'Baseball::Master' );
    
    # set the page object if used (highly recommended on data
    # sets over 1000 records)
    $cdbi_plugin_html->pager_object( $pager );
    
    # indicate the style of navigation to provide
    $cdbi_plugin_html->navigation_style( 'both' );
    
    # indicate the mapping of database column name
    # to display/friendly name
    $cdbi_plugin_html->column_to_label( {
                               lastname => 'Last Name',
                               firstname => 'First Name',
                            }
                          );
 
  print qq~<fieldset><legend>Filter by First Letter of Last Name</legend>~;

  print $cdbi_plugin_html->string_filter_navigation(
    -column       => 'lastname',
    -position     => 'begins',
  );

  print qq~</fieldset>~;

  print $cdbi_plugin_html->build_table(
    firstname => 'only',
    wt        => 'only',
 );

 my $nav = $cdbi_plugin_html->html_table_navigation();

 print qq!<div algin="center">$nav</div>\n!;

 $cdbi_plugin_html->add_bottom_span($nav);
     
 print $cdbi_plugin_html->data_table;

 # now to create a form we do the following
 
 my $user = Table::User->retrieve(1);

 #my $form = Table::User->build_form(

 # OR if you want to use the data record to fill in the form
 # make the form via a object versus the class.

 my $cdbi_form = $user->build_form(
      
 );
 
 # you can access the rows of the table via the HTML::Table
 # methods using the form_table method
 
 # $cdbi_form->form_table->addRow(-1,'');
 
 print $cdbi_form;

 # to use a prepopulated form you would do something like
 # this
 
 my $params = { lastname => 'HANK', firstname => 'AARON' };
 my $ignore = [ 'lahmanid' ];
 my $form = $cdbi_form->form_table();
 
 print $cdbi_form->fill_in_form(
    scalarref     => \$form,
    fdat          => $params,
    ignore_fields => $ignore
 );

=head1 DESCRIPTION

Note: Major changes to the object and methods have occured in this
release (.8).  It is highly likely that programs built to work with earlier
versions of this module will no longer work.

The intention of this module is to simplify the creation of HTML 
tables and forms without having to write the HTML, either in your 
script or in templates.

This module is semi-stable, but production use is still not advised.
If the maintainer is lazy and this warning appears in a 1.x or greater
release you can ignore it.

Feedback on this module, its interface, usage, documentation etc. is
welcome.

The use of HTML::Table was selected because it allows for several
advanced sorting techniques that can provide for easy manipulation
of the data outside of the SQL statement.  This is very useful in
scenarios where you want to provide/test a sort routine and not write
SQL for it.

It is intended for use inside of other frameworks such as Embperl,
Apache::ASP or even CGI.  It does not aspire to be its own framework.
If you are looking for a framework based on Class::DBI I suggest you
look into the Maypole module.


=head1 FilterOnClick

The reason for this module is to provide a generic method
of a technique I codifed in 2000 inside some one off CGI
scripts.  That technique within its problem space produced a
significantly easier to navigate database record view/action
system for those that used it.  While the current status 
(version .8 at the time of this writing) isn't a complete
representation of the tool, I hope that it will provide enough
so that others can contribute their ideas on how to improve the
design and make it more generic.

The concept, at its core, is relatively simple in nature.
You get a table of records, for our example lets assume we
have four columns: "First Name" aka FN, "Last Name" aka LN , "Address" ,
and "Email".  These columns are pulled from the database and placed
into an HTML table on a web page.  The values in the FN , LN and Email 
address columns are links back to the script that generated the original
table, but contain filter information within the query string.
In other words the link holds information that will modify the SQL query
for the next representation of data.  

Presently there are two built in table level assign and 3 more that
are specific to string based matches outside of the table itself.
(see string_filter_navigation method below)

The two table level filters are 'only' and 'like'. 'only' is an
"=" in the SQL statement.  The 'like' is a 'LIKE' clause in the SQL
query. The where clause that is 
created within the module automatically is passed through to the
Class::DBI::AbstractSearch module, which is in turn based on the
SQL::Abstract module.

Back to the example at hand.  Lets say the database has 20K records
the sort order was set to LN by default.  In the FN list you see the
FN you are looking for so you click on it, when the script runs it
generates a new query that now only shows (filters) records that match that FN.
If you click on the FN column a second time the filter based on
FN is removed.

The filter of the table is cascading, you can perform it across
multiple columns.  So if you want to find all the 'Smith's' with email
addresses like 'aol.com' you could click first on an email address
containing 'aol.com' and then a last name of 'Smith', provided you
configured a proper 'LIKE' map.

You can see FilterOnClick in action at:
http://cdbi.gina.net/cdbitest.pl

=head1 ACCESSORS

query_string (string) - sets or returns the query_string used when creating links

page_name (string) - sets or returns the page_name the script is running under

where (hash ref) - sets or returns the where clause to pass into
Class::DBI::AbstractSearch

display_columns (array ref) - sets or returns the columns and order
of the columns to be displayed in the generated table or form.

exclude_columns (array ref) - sets or returns which columns to remove
from display

data_table (object) - sets or returns a HTML::Table object (created via a call
to the html_table method)

form_table (object) - sets or returns a HTML::Table object (created via a call
to the html_table method)

pager_object (object) - sets or returns the pager object which is a Class::DBI::Pager
object

navigation_style (string) - sets or returns the navigation style to create in the
html_navigation method.

column_to_label (hash ref) - sets or

cdbi_class (string) - sets or returns the table class the HTML is being generated for

order_by (string) - sets or returns the column results are ordered by

=head1 METHOD NOTES

Parameters used on more then one method have been provided accessors
to remove the need to resend the parameters multiple times.  The accessors
and their parameter level equals share the same names.  This was a major
change in the .8 release.
Parameters that are specific to particular method are only assignable by
passing in the key value pair.

The parameters are passed in via a hash for most of the methods,
the Class::DBI::Plugin::HTML specific keys in the hash are preceeded
by a hypen (-).  Column names can be passed in with there own
anonymous subroutine (callback) if you needed to produce any
special formating or linkage.  Column names do not require a hyphen.



=head1 METHODS

=cut

=head2 html_table

returns an HTML::Table object, this is a public method and accepts a hash as its
constructor options.  See HTML::Table for valid arguments.

=cut

sub html_table : Plugged {
    my ( $self, %args ) = @_;
    my $new_table = HTML::Table->new(%args);
    $self->data_table( $new_table );
    $self->form_table( $new_table );
}

=head2 build_table

Accepts a hash of options to define the table parameters and content.  This method
returns an HTML::Table object.
   
See Synopsis above for an example usage.

The build_table method has a wide range of paramters that are mostly optional.

-display_columns (array ref, optional (has equivalent accessor) ) - The list of field names you want to create the
columns from. If not sent the order the fields in the database will
appear will be inconsistent.

-exclude_columns (array ref, optional (has equivalent accessor) ) - Don't show these fields even if included in the columns.
Useful if you are not setting the columns or the columns are dynamic and you
want to insure a particular column (field) is not revealed.

-data_table (HTML::Table Object, optional (has equivalent accessor) ) - Allows for you to pass in an HTML::Table object, this is handy
if you have setup the column headers or have done some special formating prior to
retrieving the results. 

-pager_object (Class::DBI::Pager Object, optional (has equivalent accessor) ) - Allows you to pass in a Class::DBI::Pager based object. This is useful in conjunction with the html_table_navigation method.  If not passed in
and no -records have been based it will use the calling class to perform the
lookup of records.

-records (array ref, optional) - Expects an anonymous array of record objects. This allows for
your own creation of record retrieval methods without relying on the underlying techniques
of the build_table attempts to automate it.

-where (Hash Ref, optional (has equivalent accessor) ) - Expects an anonymous hash that is compatiable with Class::DBI::AbstractSearch The url_and_where_statement method possibly can help
you dynamically create these.

-order_by (scalar, optional (has equivalent accessor) ) - This is passed along with the -where OR it is sent to the retrieve_all_sort_by method if present.  The retrieve_all_sort_by method is part of the Class::DBI::Plugin::RetrieveAll module.

-page_name (scalar (has equivalent accessor) ) - Used to create the links for the built in 'ONLY' and 'LIKE' utilities

-query_string (scalar, optional (has equivalent accessor) ) - passed to the anonymous subroutines that might be available for a particular column.

-rowcolor (optional) - determines the alternate row backgroud color, default is '#c0c0c0'

-rowclass (optional) - overrides the -rowcolor above and assigns a class (css) to table rows

table_field_name (code ref || (like,only) , optional) - You can pass in anonymous subroutines for a particular field by using the table
field name (column).  Example:
    
    first_name => sub {
       my ($name,$turl) = @_;
                         
       if ($turl =~ /ONLY\-first_name/) {
           $turl =~ s/ONLY\-first_name=[\w\-\_]+//;
       } else {
           $turl .= "&ONLY-first_name=$name";
       }
       return qq!<a href="test2.pl?$turl">$name</a>!;
    },

Optionally you can use the built-in FilterOnClick utilities of 'ONLY' and 'LIKE'.
The example above is the basis of the process, but is provided as a built-in accessible by
using:

   first_name => 'only',

The 'only' can could be  replaced with 'like' and is case insensitive.

NOTE: If you use 'like' you will need to have a proper -like_column_map hashref
assigned in your search_ref call.

=cut

sub determine_columns : Plugged {
    my ($self,$columns) = @_;
    my $class;
    
    if ( !$self->isa('Class::DBI::Plugin') ) {
        $class = $self;
    } else {
        $class = $self->cdbi_class();
    }
    
    my @columns;
    if (ref $columns eq 'ARRAY') {
        @columns = @{ $columns };
    }
    
    if ( !@columns && ref $self->display_columns() eq 'ARRAY' ) {
        @columns = @{ $self->display_columns() };
    }
    
    if ( !@columns ) { @columns = $class->columns(); }
        
    return @columns;
}

sub build_table : Plugged {
    my ( $self, %args ) = @_;
    
    my $table        = $args{-data_table}           || $self->data_table();
    if (!$table->isa( 'HTML::Table' ) ) {
         $table = HTML::Table->new();
    }
    my $table_obj    = $args{-pager_object}    || $self->pager_object();
    my $page_name    = $args{-page_name}       || $self->page_name();
    my $query_string = $args{-query_string}    || $self->query_string();
    my $exclude      = $args{-exclude_columns} || $self->exclude_columns() || 0;
    my $where        = $args{-where}           || $self->where();
    my $order_by     = $args{-order_by}        || $self->order_by();
    
    my $class;
    
    my @columns = $self->determine_columns($args{-display_columns});
    
    if ( !@columns ) {
        warn
          "Array 'columns' was not defined and could not be auto identified\n";
    }
    
    if ( $exclude eq 'ARRAY' ) {
        @columns = $self->_process_excludes( $exclude, @columns );
    }
    my @records;

    if ( ref $args{-records} eq 'ARRAY' ) {
        @records = @{ $args{-records} };
    }
    else {
	
        if ( ref $where ne 'HASH' ) {
            if ( defined $order_by ) {
                @records = $table_obj->retrieve_all_sorted_by( $order_by );
            }
            else {
                @records = $table_obj->retrieve_all;
            }

        }
        else {

            
            @records =
              $table_obj->search_where( $where ,
                { order => $order_by } );
        }

    }
    my $count;
    
    foreach my $rec (@records) {
        $count++;
        my @row;
        foreach (@columns) {

            print "col = $_\n" if $debug;
            if ( ref $args{$_} eq 'CODE' ) {
                push @row, $args{$_}->( 
		             $rec->$_,
			     $query_string
			     );
            }
            elsif ( $args{$_} =~ /only|like|beginswith|endswith|contains/i ) {

                # || $args{$_} eq 'LIKE') {
                # send script, column, value, url
                push @row,
                  _value_link( $args{$_}, 
		               $page_name ,
			       $_,
			       $rec->$_,
			       $query_string );
            }
            else {
                push @row, $rec->$_;

            }
        }
        $table->addRow(@row);
	if ( ($count % 2 == 0) && $args{-rowclass} ne '' ) {
            $table->setRowClass( -1, $args{-rowclass} );
	} elsif ( ($count %2 == 0) && $args{-rowclass} eq '') {
	    $table->setRowBGColor( -1, $args{-rowcolor} || '#c0c0c0' );
	}
	
	
	# if defined $args{-rowclass};
    }
    return $table;
}

=head2 build_form

Accepts a hash of options to define the form options.  Values can be left blank for the
value on keys in form element names if you want to use the form fill in technique described
in this document.

 #!/usr/bin/perl

 use CDBIBaseball;
 use Data::Dumper;
 use URI::Escape;
 use CGI;
 use strict;

 my $cgi = CGI->new();
 my $html = Baseball::Master->html();

 print $cgi->header();

 my %params;

 map { $params{$_} = 
       uri_unescape($cgi->param("$_"))
    } $cgi->param();

 $html->html_table(-align=>'center');

 $html->params( \%params );

    $html->page_name('formcdbitest.pl');
    $html->display_columns(     [ 'lastname','firstname',
                  'bats'    ,'throws',
                  'ht_ft'   ,'ht_in',
                  'wt'      ,'birthyear' ]
 );

    $html->exclude_columns();
    $html->hidden_fields( { lahmanid => '1234' } );
    $html->cdbi_class( 'Baseball::Master' );
    $html->navigation_style( 'both' );
    $html->column_to_label( {
                               lastname  => 'Last Name',
                               firstname => 'First Name',
                               bats      => 'Bats',
                               ht_ft     => 'Height (ft)',
                               ht_in     => 'Height (in)',
                               wt        => 'Weight',
                               birthyear => 'Birthyear',
                               throws    => 'Throws', 
                            }
                          );
 print $html->build_form();

The submit button can be removed by sending -no_submit as an attribute to the build_form
method.

The form tag can be removed by sending -no_from_tag as an attribute to the build_form
method.

Hidden fields can be added by putting a hash ref into the hidden_fields accessor or by
sending in a hash ref with the -hidden_fields attribute of the build_form method.

=cut

sub build_form : Plugged {

    my ( $self, %args ) = @_;

    my $html_table = $args{-form_table} || $self->form_table(); 
    if (!$html_table->isa( 'HTML::Table' ) ) {
         $html_table = HTML::Table->new();
    }
    my @columns    = $self->determine_columns($args{-display_columns});
    my $labels     = $args{-column_to_label} || $self->column_to_label();
    my $hidden     = $args{-hidden_fields}   || $self->hidden_fields();
    my $exclude    = $args{-exclude_columns} || $self->exclude_columns() || 0;
    
    if ( !@columns ) {
        warn
          "Array 'display_columns' was not defined and could not be auto identified\n";
    }
    if ( ref $exclude eq 'ARRAY' ) {
        @columns = $self->_process_excludes( $exclude , @columns );
    }

    my %cgi_field = $self->to_cgi;

    foreach my $col (@columns) {
        my $cell_content;
        if ( ref $args{$col} eq 'CODE' ) {
            $cell_content = $args{$col}->( $cgi_field{$col}->as_HTML() );
        }
        else {

            $cell_content = $cgi_field{$col}->as_HTML();
        }

        $html_table->addRow( $labels->{$col} || $col, $cell_content );
        $html_table->setRowClass( -1, $args{-rowclass} )
          if defined $args{-rowclass};
    }

    if ( !$args{-no_submit} ) {
        $html_table =
          $self->_process_attributes( $args{-attributes}, $html_table );
        $html_table->addRow();
        $html_table->setCellColSpan( $html_table->getTableRows, 1,
            $html_table->getTableCols );
        $html_table->setCell( $html_table->getTableRows, 1,
            CGI::submit( '.submit', 'Continue' ) );
    }

    if ( $hidden ) {
        my $corner = $html_table->getCell( 1, 1 );
        foreach my $hidden_field ( keys %{ $hidden } ) {
            next if $hidden_field !~ /\w/;
            $corner .=
qq!<input name="$hidden_field" type="hidden" value="$hidden->{$hidden_field}">!;
        }

        $html_table->setCell( 1, 1, $corner );
    }

    if ( !$args{-no_form_tag} ) {
        $html_table =
          start_form( $args{-form_tag_attributes} ) . $html_table . end_form;
    }

    return $html_table;

}

sub _process_attributes : Plugged {
    my ( $self, $attributes, $html_table ) = @_;
    foreach ( keys %{$attributes} ) {
        if ( ref $attributes->{$_} eq 'ARRAY' ) {
            print "doing a $_\n" if $debug;
            $html_table->$_( @{ $attributes->{$_} } );
        }
        else {
            $html_table->$_( $attributes->{$_} );
        }
    }
    return $html_table;
}

sub _process_excludes : Plugged {

    my ( $self, $exclude_list, @columns ) = @_;
    my %exclude;
    map { $exclude{$_} = 1 } @{$exclude_list};
    print "excluding\n" if $debug;
    map { undef $_ if exists $exclude{$_} } @columns;
    return grep /\w/, @columns;
}

sub _value_link {

    my ( $type, $page_name, $column, $name, $turl ) = @_;
    my $ourl = $turl;
    $type = uc($type);
    my $otype = $type;
    my $add_item = 1;
    
    # if the incoming request matches a current filter
    # we remove that filter from the turl and return the turl
    if ( $turl =~ /$type\-$column=/ ) {
         $turl =~ s/$type\-$column=[\w\-\_]+//;
	 $add_item = 0;
    } 

    my $link_val = $name;
    
    $link_val = 1 if $type =~ /like|begin|end|contain/i;
    
    
    # add the string to the type is we are doing
    # a begin,end or contain link
    
    if ( $type =~ /begin|end|contain/i ) {
         $type .= $name;
    }
    
    # remove the filter from the url if we
    # already had one in the current string
        
    if ( $turl =~ m/$type\-$column\=1/ ) {
         $turl =~ s/$type\-$column\=1//;
         $add_item = 0;
    }

    if ( $turl =~ m/$otype\w+\-$column\=/) {
         $turl =~ s/$otype\w+\-$column\=1//;
	 print "Just removed $otype<br>" if $debug;
    }
        
    if ($add_item == 1) {
            $turl .= "&$type-$column=$link_val";
    }
 
       print qq~<br>type: $type 
    <br> page: $page_name 
    <br> column: $column 
    <br> name: $name 
    <br> turl: $turl
    <br> ourl: $ourl
    <br>~ if $debug;
       
    return qq!<a href="$page_name?$turl">$name</a>!;

}

=head2 html_table_navigation

Creates HTML anchor tag (link) based navigation for datasets. Requires Class::DBI::Pager.
Navigation can be in google style (1 2 3 4) or block (previous,next).

    my $nav = $cdbi_plugin_html->html_table_navigation(
                        -pager_object      => $pager,
                        # pass in -navigation with block as the value for
                        # next/previous style 
                        # "google" style is the default
                        -navigation_style   => 'block',
                        -page_name          => 'test2.pl', 
                   );

    print "'$nav'\n";

=cut

sub html_table_navigation : Plugged {
    my ( $self, %args ) = @_;
    my $pager = $args{-pager_object} || $self->pager_object();

    my $nav_block;
    my $nav_number;
    my $page_name        = $args{-page_name}    || $self->page_name();
    my $query_string     = $args{-query_string} || $self->query_string();
    my $navigation_style = $args{-navigation_style}   || $self->navigation_style();
    
    my $first_page_link = CGI::a(
	        {
		  href => "$page_name?page="
                      . $pager->first_page . '&'
                      . $query_string
		},'first'
		);
    
    my $last_page_link = CGI::a(
	       {
		  href => "$page_name?page="
                      . $pager->last_page . '&'
                      . $query_string
		},'last'
		);
    
    if (   defined $navigation_style
        && defined $page_name )
    {

        if ( $pager->previous_page ) {
            $nav_block .= CGI::a(
                {
                        href => "$page_name?page="
                      . $pager->previous_page . '&'
                      . $query_string
                },
                'prev'
            );

        }

        if ( $pager->previous_page && $pager->next_page ) {
            $nav_block .= ' | ';
        }

        if ( $pager->next_page ) {
            $nav_block .= CGI::a(
                {
                        href => "$page_name?page="
                      . $pager->next_page . '&'
                      . $query_string
                },
                'next'
            );
        }

		
        #} else {
	
	# determine paging system
	# need to allow for "to first" and "to last" record list
	# need to allow for "next" and "previous"
	# need to show which record group we are on
	# need to limit the list of records via an argument and/or
	# a reasonable default.
	
	if ( ($pager->total_entries / $pager->entries_per_page) > 10 ) {
	
	    my $left = $pager->last_page - $pager->current_page;
	    my $offset = $left;
	    if ($left > 9) {
	       $offset = 9;
	    } 
	    foreach my $num ( $pager->current_page .. $offset + $pager->current_page ) {
	     $nav_number .= add_number($pager->current_page,$num,$page_name,$query_string);
	    }    
	
	} else {
	
        foreach my $num ( $pager->first_page .. $pager->last_page ) {
             # $current,$number,$page_name,$query_string
	     $nav_number .= add_number($pager->current_page,$num,$page_name,$query_string);
        }
        
	}
        #}
    }

    $nav_number = '' if $nav_number =~ /\[ 1 \]\s$/;

    my $nav = $nav_number;

    # warn "'$nav_number'\n";

    if ( lc( $navigation_style ) eq 'both' ) {
        if ( $nav_block =~ /\|/ ) {
            $nav_block =~ s/ \| / $nav_number/;
            $nav = $nav_block;
        }
        elsif ( $nav_block =~ m#prev</a>$# ) {
            $nav = $nav_block . ' ' . $nav_number;
        }
        else {
            $nav = $nav_number . ' ' . $nav_block;
        }

    }

    if ( $navigation_style eq 'block' ) {
        $nav = $nav_block;
    }
    
    return $first_page_link . " " . $nav . " $last_page_link";
}

sub add_number {
   my ($current,$num,$page_name,$query_string) = @_;
   my $nav_num;
            if ( $num == $current ) {
                $nav_num .= "[ $num ]";
            }
            else {
                $nav_num .= '[ ';
                $nav_num .= CGI::a(
                    {
                        href =>
                          "$page_name?page=$num&$query_string"
                    },
                    $num
                );
                $nav_num .= ' ]';
            }
            $nav_num .= ' ';
    return $nav_num;
}

=head2 fill_in_form

Wrapper method for HTML::FillInForm, pass the arguments you would normally
pass into HTML::FillInForm.

    my $params = { user_name => 'trs80', first_name => 'TRS' };
    my $ignore = [ 'last_name' ];

    print $html->fill_in_form(
        scalarref     => \$form,
        fdat          => $params,
        ignore_fields => $ignore
    );

=cut

sub fill_in_form : Plugged {
    my ( $self, %args ) = @_;
    my $fif = new HTML::FillInForm;
    return $fif->fill(%args);

}

=head2 add_bottom_span

Places the content you pass in at the bottom of the HTML::Table
object passed in.  Used for adding "submit" buttons or navigation to
the bottom of a table.

=cut

sub add_bottom_span : Plugged {
    my ( $self, $add ) = @_;
    $self->data_table->addRow();
    $self->data_table->setCellColSpan( $self->data_table->getTableRows, 
                                       1,
                                       $self->data_table->getTableCols );
    $self->data_table->setCell( $self->data_table->getTableRows, 1, $add );
    # return $table;
}

=head2 search_ref

Creates the URL and where statement based on the parameters based
into the script. This method sets the query_string accessor value
and returns the where hash ref.

   $cdbi_plugin_html->search_ref( 
           # hash ref of incoming parameters (form data or query string)
           # can also be set via the params method instead of passed in
	   -params => \%params,
          
           # the like parameters by column (field) name that the
           # SQL statement should include in the where statement
           -like_column_map  => { 'first_name' => 'A%' },
          
   );

=head2 url_query

Creates the query portion of the URL based on the incoming parameters, this
method sets the query_string accessor value and returns the query string

    $cdbi_plugin_html->url_query(
        
	# pass in the parameters coming into the script as a hashref 
	-params => \%params,
	
        # items to remove from the url, extra data that
        # doesn't apply to the database fields
        -exclude_from_url => [ 'page' ], 
    );

=head2 string_filter_navigation

    my ($filter_navigation) = $cdbi_plugin_html->string_filter_navigation(
       -position => 'ends'
    );

This method creates navigation in a series of elements, each element indicating a item that
should appear in a particular column value.  This filter uses anchor points to determine how
to qualify the search.  The anchor points are:
   BEGINSWITH
   ENDSWITH
   CONTAINS

The items in the 'strings' list will only be hrefs if they items in the database match the search, if you prefer them not to be displayed at all pass in the -hide_zero_match

The allowed parameters to pass into the method are:

-hide_zero_match - Removes items that have no matches in the database from the strings allowed in the final navigation.

-position (optional - default is 'begin') - Tells the method how to do the match, allowed options are any case
of 'begin' , 'end' or 'contains'.  These options can be the entire anchor points as outlined above,
but for ease of use only the aforemention is enforced at a code level.

-query_string (optional) - This is the same as the parameter outlined in build_table above.

-strings (optional, array_ref - default is A-Z) - Array ref containing the strings to filter on.

-column - Indicates which column the string filter will occur on. If you want to provide a filter on multiple columns it is recommended that you create multiple string_filter_navigation.

-page_name - The name of page that the navigation should link to

-seperator (optional, default two non-breaking spaces) - The characters to place between each item in the list.

-align (optional, defaults to center) - defines the alignment of the navigation

-no_reset - don't include the table reset link in the output

=cut

sub string_filter_navigation : Plugged {

    # intent of sub is to provide a consistent way to navigate to find
    # records that contain a particular string.
    my ( $self, %args ) = @_;

    # set up or variables and defaults

    my @links;
    my @alphabet = @{ args{-strings} } || ( 'A' .. 'Z' );
    $args{-separator} ||= '&nbsp;&nbsp;';
    $args{-align}     ||= 'center';
    my $page_name    = $args{-page_name}    || $self->page_name();
    my $query_string = $args{-query_string} || $self->query_string();
    
    if ( $args{-no_reset} == 0 ) {
        push @links, qq!<a href="$page_name">Reset</a>$args{-separator}!;
    }
    my $filter;
    my $link_text;
    foreach my $string (@alphabet) {

        if ( $args{-position} =~ /ends/i ) {
            $filter    = "\%$string";
            $link_text = 'ENDSWITH';
        }
        elsif ( $args{-position} =~ /contain/i ) {
            $filter    = "\%$string\%";
            $link_text = 'CONTAINS';
        }
        else {
            $filter    = "$string\%";
            $link_text = 'BEGINSWITH';
        }

        my $count = $self->cdbi_class()->count_search_where(
                      $args{-column} => { like => "$filter" }
                                               );
        if ($count) {

# send script, column, value, url

# ($type,$page_name,$column,$name,$turl)
            push @links,
              _value_link( $link_text, $page_name, $args{-column},
                $string, $query_string );

# qq!<a href="$args{-page_name}?$link_text$string-$args{-column}=1">$string</a>!;
        }
        elsif ( $args{-hide_zero_match} > 1 ) {

            # do nothing
        }
        else {
            push @links, qq!$string!;
        }

    }

    return qq!<div align="$args{-align}">!
      . join( $args{-separator}, @links )
      . "</div>";
}

sub search_ref : Plugged {
    my ( $self, %args ) = @_;

    $args{-params} ||= $self->params();
    my %where;
    if ( exists $args{-exclude_from_url} ) {

        # print_arrayref("Exclude from URL",$args{-exclude_from_url});
        map { delete $args{-params}->{$_} } @{ $args{-exclude_from_url} };
    }

    if ( exists $args{-params} ) {

        # print_hashref("Incoming parameters",$args{-params});
        my @only       = grep /ONLY\-/,        keys %{ $args{-params} };
        my @like       = grep /LIKE\-/,        keys %{ $args{-params} };
        my @beginswith = grep /BEGINSWITH\w+/, keys %{ $args{-params} };
        my @endswith   = grep /ENDSWITH\w+/,   keys %{ $args{-params} };
        my @contains   = grep /CONTAINS\w+/,   keys %{ $args{-params} };

        if (@only) {
            warn "\tOnly show matches of:\n" if $debug;
            foreach my $only (@only) {
	        print $only if $debug;
                $only =~ s/ONLY-//;

    # print qq~\t\t$only becomes $only = '$args{-params}->{"ONLY-" . $only}'\n~;
                $where{$only} = $args{-params}->{ "ONLY-" . $only };
            }

        }

        if (@like) {

            # print "\tLike clauses to be added\n";
            foreach my $like (@like) {
                $like =~ s/LIKE-//;

# print "\t\t$like becomes \"first_name LIKE '$args{-like_column_map}->{$like}'\"\n";
                if ( exists $args{-like_column_map}->{$like} ) {

                    $where{$like} =
                      { 'LIKE', $args{-like_column_map}->{$like} };
                }
            }
        }

        if (@beginswith) {
            warn "\tShow only begining with\n" if $debug;
            foreach my $beginswith (@beginswith) {
                my ( $value, $column ) =
                  $beginswith =~ m/beginswith(\w+)-([\w\_]+)/i;
                warn
qq~\t\t'$beginswith' - looking $column that begins with $value\n~;
                $where{$column} = { 'LIKE', "$value\%" };
            }
        }

        if (@endswith) {
            warn "\tShow only endswith with\n" if $debug;
            foreach my $endswith (@endswith) {
                my ( $value, $column ) =
                  $endswith =~ m/endswith(\w+)-([\w\_]+)/i;
                warn
                  qq~\t\t'$endswith' - looking $column that ends with $value\n~;
                $where{$column} = { 'LIKE', "\%$value" };
            }
        }

        if (@contains) {
            warn "\tShow only entries that contain\n" if $debug;
            foreach my $contains (@contains) {
                my ( $value, $column ) =
                  $contains =~ m/contains(\w+)-([\w\_]+)/i;
                warn
                  qq~\t\t'$contains' - looking $column that contain $value\n~;
                $where{$column} = { 'LIKE', "\%$value\%" };
            }
        }

    }

    if ( scalar( keys %where ) > 0 ) {
        $self->where( \%where );
        return \%where;
    }
    else {
        $self->where( undef );
        return undef;
    }

}

sub url_query : Plugged {
    my ( $self, %args ) = @_;
    $args{-params} ||= $self->params();
    if ( exists $args{-exclude_from_url} ) {
        map { delete $args{-params}->{$_} } @{ $args{-exclude_from_url} };
    }
    my %Param = %{ $args{-params} };
    my @url;
    foreach my $key ( keys %Param ) {

        if ( $key =~ m/\w/ && $Param{"$key"} ) {
            push @url, qq~$key=~ . uri_escape( $Param{"$key"} )
              if $Param{"$key"} ne '';
        }
    }

    if ( $url[0] ) {
        $self->query_string( join( '&', @url ) );
        return join( '&', @url );
    }
    else {
        $self->query_string( undef );
        return undef;
    }
}

sub form_select : Plugged {
    my ( $self, %args ) = @_;

    my $html;
    my @objs         = $self->get_records(%args);
    my $value_column = $args{'-value_column'};
    my $text_column  = $args{'-text_column'};
    my $divider      = $args{'-text_divider'};
    $divider         ||= ', ';
    foreach my $obj (@objs) {
        my $text;
        my $value = $obj->$value_column();
        if ( ref($text_column) eq 'ARRAY' ) {
            my @text_multiple;
            foreach my $tc ( @{$text_column} ) {
                push @text_multiple, $obj->$tc();
            }
            $text = join( $divider, @text_multiple );
        }
        elsif ($text_column) {
            $text = $obj->$text_column();
        }
        else {
            $text = $value;
        }
        my $selected;
        $selected = ' SELECTED' if $value eq $args{'-selected_value'};
        $html .= qq!<option value="$value"$selected>$text</option>\n!;

    }
    if ( $args{no_select_tag} == 0 ) {
        $html = qq!<select name="$args{'-value_column'}">
       $html
</select>!;
    }
    return $html;
}

sub get_records : Plugged {

    # this code was taken from the build_table method
    # due to a limitation of the Class::DBI::Pager module and/or the way
    # in which this module identifies itself this code is currently replicated
    # here since Class::DBI::Pager throws and error when used.
    # behavior was retested with Class::DBI::Plugin and problem persisted

    my ( $table_obj, %args ) = @_;
    my $order_by = $args{-order_by} || $table_obj->order_by();
    if ( $table_obj->isa('Class::DBI::Plugin::HTML') ) {
        $table_obj = $table_obj->cdbi_class() ||
	             $table_obj->pager_object()
		     
    }
    warn Dumper($table_obj) if $debug;
    my @records;
    if ( ref $args{-where} ne 'HASH' ) {
        if ( defined $order_by ) {
            @records = $table_obj->retrieve_all_sorted_by( $order_by );
        }
        else {
            @records = $table_obj->retrieve_all;
        }

# @records = $table_obj->search( user_id => '>0' , { order_by => $args{-order} } );
    }
    else {

        # my %attr = $args{-order};
        @records =
          $table_obj->search_where( $args{-where}, { order => $order_by } );
    }
    return @records;
}

=head2 form_select

this methods expects the following:

    -value_column    # column containing the value for the option in the select
    -text_column     # column containing the text for the optoin in the select (optional)
    -selected_value  # the value to be selected (optional)
    -no_select_tag   # returns option list only (optional)

=head1 BUGS

Unknown at this time.

=head1 SEE ALSO

Class::DBI, Class::DBI::AbstractSearch, Class::DBI::AsForm, HTML::Table, Class::DBI::Pager

=head1 AUTHOR

Aaron Johnson
solution@gina.net

=head1 THANKS

Thanks to my Dad for buying that TRS-80 in 1981 and getting
me addicted to computers.

Thanks to my wife for leaving me alone while I write my code
:^)

The CDBI community for all the feedback on the list and
contributors that make these utilities possible.

=head1 CHANGES

Changes file included in distro

=head1 COPYRIGHT

Copyright (c) 2004 Aaron Johnson.
All rights Reserved. This module is free software.
It may be used,  redistributed and/or modified under
the same terms as Perl itself.

=cut

# experimental accessors below

sub query_string : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{query_string} = shift;
      }
      elsif(@_ > 1) {
          $self->{query_string} = [@_];
      }

      return $self->{query_string};
  }

sub page_name : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{page_name} = shift;
      }
      elsif(@_ > 1) {
          $self->{page_name} = [@_];
      }

      return $self->{page_name};
  }

sub where : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{where} = shift;
      }
      elsif(@_ > 1) {
          $self->{where} = [@_];
      }

      return $self->{where};
  }

sub display_columns : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{display_columns} = shift;
      }
      elsif(@_ > 1) {
          $self->{display_columns} = [@_];
      }

      return $self->{display_columns};
  }

sub exclude_columns : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{exclude_columns} = shift;
      }
      elsif(@_ > 1) {
          $self->{exclude_columns} = [@_];
      }

      return $self->{exclude_columns};
  }

sub data_table : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{data_table} = shift;
      }
      elsif(@_ > 1) {
          $self->{data_table} = [@_];
      }

      return $self->{data_table};
  }

sub form_table : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{form_table} = shift;
      }
      elsif(@_ > 1) {
          $self->{form_table} = [@_];
      }

      return $self->{form_table};
  }

sub pager_object : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{pager_object} = shift;
      }
      elsif(@_ > 1) {
          $self->{pager_object} = [@_];
      }

      return $self->{pager_object};
  }

sub navigation_style : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{navigation_style} = shift;
      }
      elsif(@_ > 1) {
          $self->{navigation_style} = [@_];
      }

      return $self->{navigation_style};
  }

sub column_to_label : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{column_to_label} = shift;
      }
      elsif(@_ > 1) {
          $self->{column_to_label} = [@_];
      }

      return $self->{column_to_label};
  }

sub cdbi_class : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{cdbi_class} = shift;
      }
      elsif(@_ > 1) {
          $self->{cdbi_class} = [@_];
      }

      return $self->{cdbi_class};
  }

sub order_by : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{order_by} = shift;
      }
      elsif(@_ > 1) {
          $self->{order_by} = [@_];
      }

      return $self->{order_by};
  }

sub params : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{params} = shift;
      }
      elsif(@_ > 1) {
          $self->{params} = [@_];
      }

      return $self->{params};
  }

sub hidden_fields : Plugged {
      my $self = shift;

      if(@_ == 1) {
          $self->{hidden_fields} = shift;
      }
      elsif(@_ > 1) {
          $self->{hidden_fields} = [@_];
      }

      return $self->{hidden_fields};
  }
  
1;
