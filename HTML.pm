package Class::DBI::Plugin::HTML;

use base qw( Class::DBI::Plugin );

our $VERSION = 0.9;
use HTML::Table;
use HTML::FillInForm;
use CGI qw/:form/;
use Class::DBI::AsForm;
use Data::Dumper;
use URI::Escape;
use Config::Auto;
use strict;

our $config_hash = {};
our $debug = 0;

our @allowed_methods = qw(
rows
exclude_from_url
display_columns
cdbi_class
page_name
column_to_label
descending_string
ascending_string
mouseover_bgcolor
mouseover_class
no_form_tag
no_mouseover
no_reset
no_submit
debug
searchable
rowclass
rowclass_odd
rowcolor_even
rowcolor_odd
filtered_class
navigation_list
navigation_column
navigation_style
navigation_alignment
page_navigation_separator
navigation_separator
hide_zero_match
query_string
data_table
form_table
order_by
hidden_fields
auto_hidden_fields
config_file
);

sub output_debug_info : Plugged {
    my ($self,$message,$level) = @_;
    $level ||= $debug;
    return undef if $level == 0;
    if ($level == 2) {
        print "$message\n";
    }
    
    if ($level == 1) {
        warn "$message\n";
    }
}

sub read_config : Plugged {
    my ($self,$config_file) = @_;
    my $config = Config::Auto::parse($config_file);

    my $base = $config->{cdbi_class};
    $base =~ s/\s//g;
    
    $config->{config_file} = $config_file;
    foreach my $config_key (keys %{$config}) {
        next if !grep /$config_key/ , @allowed_methods;
        next if !defined $config->{$config_key};
        # change ~ to space
        $config->{$config_key} =~ s/~/ /g;
        $config->{$config_key} =~ s/[\r\n]+$//;
        $self->output_debug_info( "assigning: $config_key" );
        if ($config->{$config_key} =~ /\|/) {
            my @values = split(/\|/,$config->{$config_key});
            $config->{$config_key} = \@values;
        }
        if ($config_key eq 'debug') {
            $debug = $config->{$config_key};
        } else {
            $self->$config_key($config->{$config_key});
        }
    }   
    $self->output_debug_info( Dumper($config) );
}

sub html : Plugged {
    my ( $class, %args ) = @_;

    my $self = bless {
    }, $class;
 
    # add code for configuration file based settings
    $self->output_debug_info( "conf = $args{-config_file}" );
    
    if (defined $args{-config_file}) {
        $self->read_config( $args{-config_file} );
    }
     
    # $config_hash = $config;
    my $rows = $args{-rows} || $self->rows() || 15;
    if ($rows) {
        $self->pager_object($self->pager($rows,$args{-on_page}));
    }
    
    # end code for configuration based settings
    
    $self;
}

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

 use ClassDBIBaseClass;
 use URI::Escape;
 use CGI;
 
 my $cgi = CGI->new();
 
 my $cdbi_plugin_html = Baseball::Master->html();
 
 $cdbi_plugin_html->data_table->addRow('Last Name','First Name','Bats' , 'Throws' ,
                    'Height (ft)','(inches)',
                    'Weight','Birth Year' );
 
 my %params;

 map { $params{$_} = 
        uri_unescape($cgi->param("$_"))
    } $cgi->param();

 $cdbi_plugin_html->params( \%params );    
 $cdbi_plugin_html->exclude_from_url([ 'page' ]);
 
 # attribute style
 # created based on params and exclude values from above
 # auto sets the query_string value
 $cdbi_plugin_html->url_query();

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
    
 # indicate the style of navigation to provide
 $cdbi_plugin_html->navigation_style( 'both' );
    
  print qq~<fieldset><legend>Filter by First Letter of Last Name</legend>~;

  print $cdbi_plugin_html->string_filter_navigation(
    -column       => 'lastname',
    -position     => 'begins',
  );

  print qq~</fieldset>~;

  $cdbi_html->only('firstname');
  

  print $cdbi_plugin_html->build_table();

 my $nav = $cdbi_plugin_html->html_table_navigation();

 print qq!<div algin="center">$nav</div>\n!;

 $cdbi_plugin_html->add_bottom_span($nav);
     
 print $cdbi_plugin_html->data_table;

=head1 UPGRADE WARNING

As of the .8 release there have been changes to the methods and how they
work.  It is likely that scripts built with older versions WILL break.  Please
read below to find specific changes that may negatively impact scripts built
using the the releases prior to .8.  The .9 release contains some minor modifications
that could in some chases break your scripts, test carefully before upgrading in
a production environment.

=head1 DESCRIPTION

The intention of this module is to simplify the creation of HTML 
tables and forms without having to write the HTML, either in your 
script or in templates.

It is intended for use inside of other frameworks such as Embperl,
Apache::ASP or even CGI.  It does not aspire to be its own framework.
If you are looking for a framework based on Class::DBI I suggest you
look into the Maypole module.

See FilterOnClick below for more on the purpose of this module.

Tables are created using HTML::Table. The use of HTML::Table was selected
because it allows for several advanced sorting techniques that can provide for
easy manipulation of the data outside of the SQL statement.  This is very useful
in scenarios where you want to provide/test a sort routine and not write
SQL for it.  The more I use this utility the less likely it seems that one would
need to leverage this, but it is an option if you want to explore it.

This module is semi-stable, but production use is still not advised.
If the maintainer is lazy and this warning appears in a 1.x or greater
release you can ignore it.

Feedback on this module, its interface, usage, documentation etc. is
welcome.

=head1 FilterOnClick

This module provides a generic implementation
of a technique I codifed in 2000 inside some one off CGI
scripts.  That technique within its problem space produced a
significantly easier to navigate database record view/action
system for those that used it.

As of release .9 98% of that functionality is replicated within this module,
plus some new features.

The concept, at its core, is relatively simple in nature.  You filter the results
in the table by clicking on values that are of interest to you. Each click turns
on or off a filter, which narrows or expands the total number of matching records.
This allows for identifying abnormal entries, trends or errors simply by paging,
searching or filtering through your data.  If you configure the table appropriately
you can even link to applications or web pages to allow you edit the records.

An example FilterOnClick session would consist of something like this:
You get a table of records, for our example lets assume we
have four columns: "First Name" aka FN, "Last Name" aka LN , "Address" ,
and "Email".  These columns are pulled from the database and placed
into an HTML table on a web page.  The values in the FN , LN and Email 
address columns are links back to the script that generated the original
table, but contain filter information within the query string.
In other words the link holds information that will modify the SQL query
for the next representation of data.  

Presently there are six (6) built in filter types for within tables and
three (3) more that are specific to string based matches outside of the table
itself. (see string_filter_navigation method below for info on the second three)

The six html table level filters are 'only','contains','beginswith','endswith'
'variancepercent','variancenumerical'. The where clause that is 
created within the module automatically is passed through to the
Class::DBI::AbstractSearch module, which is in turn based on the
SQL::Abstract module. In other words, you are not required to create any SQL
statements or add any code to your Class::DBI base class.

Back to the example at hand.  Lets say the database has 20K records
the sort order was set to LN by default. The FN column has been configured with
an 'only' filter. In the FN list you see the FN you are looking for so you click
on it, when the script runs it auto-generates a new filter (query) that now
only shows records that match the FN you clicked on.
If you click on the FN column a second time the filter based on
FN is removed.

The filter of the table is cascading, you can perform it across
multiple columns.  So if you want to find all the 'Smith's' with email
addresses like 'aol.com' you could click first on an email address
containing 'aol.com' and then a last name of 'Smith', provided you
configured a proper filter code for the table.

You can see FilterOnClick in action at:
http://cdbi.gina.net/cdbitest.pl

Example code to create a FilterOnClick column value ( see the build_table method ):

Match Exactly

  $html->only('column_name');
  column_name => 'only'

Match Beginning of column value with string provided
  
  $html->beginswith('column_name' , 'string'); # new way, can be done anywhere
  
  
Match ending of column value with string provided
  $html->endswith('column_name , 'string'); # new way, can be done anywhere

  
Filter to columns that contain a particular string (no anchor point)

  $html->contains('column_name' , 'string'); # new way, can be done anywhere 
 
Show records with a numerical variance of a column value

  $html->variancenumerical('column_name' , number); # new way, can be done anywhere

Show records with a percentage variance of a column value

  $html->variancepercent('column_name' , number); # new way, can be done anywhere

=head1 CONFIGURATION FILE

As of version .9 you can assign many of the attributes via a configuration file
See the examples directory for a sample ini file

=head1 METHOD NOTES

The parameters are passed in via a hash for most of the methods.
The Class::DBI::Plugin::HTML specific keys in the hash are preceeded
by a hypen (-).  Column names can be passed in with their own
anonymous subroutine (callback) if you needed to produce any
special formating or linkage.

=head1 METHODS

=head2 html

Creates a new Class::DBI::Plugin::HTML object

    $cdbi_html = MyClassDBIModule->html();

=head2 debug

Wants: 1 or 0

Defaults to: 0

Valid in Conifguration File: Yes

Set to one to turn on debugging output.  This will result in a considerable amount
of information being sent to the browser output so be sure to disable in production.
Can be set via method or configuration file.

    $cdbi_html->debug(1);

=head2 params

Wants: Hash reference of page paramters

Defaults to: {} (empty hash ref)

Set the params that have been passed on the current request to the page/script

    $cdbi_html->params( {
        param1 => 'twenty'
    } );
    
Using CGI

    use URI::Escape;
    my %params;

    map { $params{$_} =
           uri_unescape($cgi->param("$_"))
        } $cgi->param();

    $cdbi_html->params( \%params );
    
Using Apache::ASP

    $cdbi_html->params( $Request->Form() );
    
Using Embperl

    $cdbi_html->params( \%fdat );

=head2 config

Wants: configuration key, value is optional

Defatuls to: na

Configuration values can be accessed directly or via the config method. This is
allowed so you know where the value you are calling is being assigned from.

To get get a value:

    $cdbi_html->config("searchable");

To set a value do this:

    $cdbi_html->config('searchable',1);

=head2 display_columns

Wants: Array ref of column names

Defaults to: List of all columns available if left unassigned

Valid in configuration file: Yes

The list (array ref) of field names you want to create the
columns from. If not sent the order the fields in the database will
appear will be inconsistent. Works for tables or forms.

    $cdbi_html->display_columns( [ 'lastname','firstname',
                  'bats'    ,'throws',
                  'ht_ft'   ,'ht_in',
                  'wt'      ,'birthyear' ]
    );

=head2 exclude_from_url

Wants: Array reference

Defaults to: [] (emptry array ref)

Key/value pair to be removed from auto generated URL query strings. The key for
the page should be one of the items here to avoid navigation issues

    $cdbi_html->exclude_from_url( [ 'page' ] );

=head2 form_table

Wants: HTML::Object

Defaults to: HTML::Object

Returns: HTML::Object

    $cdbi_html->form_table(); # get current form table object
    $cdbi_html->form_table($html_table_object); # set form table object

There is no need to set this manually for simple forms.

=head2 navigation_style

Wants: string, either 'block' or 'both'

Defaults to: block

Valid in Configuration File: Yes

Returns: Current setting

    $cdbi_html->navigation_style('both');

=head2 column_to_label

Wants: Hash reference

Defaults to: empty

    $cdbi_html->column_to_label(
        'firstname' => 'First Name',
        'lastname' => 'Last Name'
    );

Presently not active, but will be in 1.0 release

=head2 cdbi_class

(string) - sets or returns the table class the HTML is being generated for

=head2 config_file

Returns the name of the config_file currently in use

=head2 rows

Wants: Number

Defaults to: 15

Sets the number of rows the table output by build_table will contain per page

    $cdbi_html->rows(20);

=head2 html_table

Wants: HTML::Table object

Defaults to: HTML::Table object

This is only useful if want to either create your own HTML::Table object and
pass it in or you want to heavily modify the resulting table from build_table.
See the L<HTML::Table> module for more information.

=cut

sub html_table : Plugged {
    my ( $self, %args ) = @_;
    my $new_table = HTML::Table->new(%args);
    $self->data_table( $new_table );
    $self->form_table( $new_table );
}

=head2 build_table

Wants: Hash reference

Defatuls to: na

Returns: HTML::Table object

Accepts a hash of options to define the table parameters and content.  This method
returns an HTML::Table object. It also sets the data_table method to the HTML::Table
object generated so you can ignore the return value and make further modifications
to the table via the built in methods.
   
See Synopsis above for an example usage.

The build_table method has a wide range of paramters that are mostly optional.

=head2 exclude_columns

Wants: Arrary reference

Defaults to: na

Valid in configuration File: Yes

Returns: When called with no argument, returns current value; an array ref

Removes fields even if included in the display_columns list.
Useful if you are not setting the columns or the columns are dynamic and you
want to insure a particular column (field) is not revealed even if someone
accidently adds it some where.

=head2 data_table

Wants: HTML::Table object

Defaults to: na

Returns: HTML::Table object is assigned

Allows for you to pass in an HTML::Table object, this is handy
if you have setup the column headers or have done some special formating prior to
retrieving the results. 

=head2 pager_object

Wants: Class::DBI::Pager object

Defaults to: Class::DBI::Pager object

Returns: Current pager_object

Allows you to pass in a Class::DBI::Pager based object. This is useful in
conjunction with the html_table_navigation method.  If not passed in
and no -records have been based it will use the calling class to perform the
lookup of records.

As of version .9 you do not need to assign this manually, it will be auto
populated when call to 'html' is made.

=head2 records

Wants: Array reference

Defaults to: na

Returns: present value

Expects an anonymous array of record objects. This allows for your own creation
of record retrieval methods without relying on the underlying techniques of the
build_table attempts to automate it. In other words you can send in records from
none Class::DBI sources, but you lose some functionality.

=head2 where

Wants: Hash reference

Defaults to: Dynamically created hash ref based on query string values, part of
the FilterOnClick process.

Expects an anonymous hash that is compatiable with Class::DBI::AbstractSearch

=head2 order_by

Wants: scalar

Returns: current value if set

Passed along with the -where OR it is sent to the retrieve_all_sort_by method
if present.  The retrieve_all_sort_by method is part of the
L<Class::DBI::Plugin::RetrieveAll> module.

=head2 page_name

Wants: scalar

Returns: current value if set

Valid in Configuration file: Yes

Used within form and querystring creation.  This is the name of the script that
is being called.

=head2 query_string

Wants: scalar

Returns: current value if set

It is not required to set this, it auto generated through the FilterOnClick
process, is useful for debugging.

=head2 rowcolor_even

Wants: Valid HTML code attribute

Defaults to: '#ffffff'

Returns: Current value if set

Valid in Configuration file: Yes

Define the even count row backgroud color

=head2 rowcolor_odd

Wants: Valid HTML code attributes

Defaults to: '#c0c0c0'

Valid in Configuration file: Yes

Define the odd count row backgroud color

=head2 rowclass


Valid in Configuration file: Yes

(optional) - overrides the -rowcolor above and assigns a class (css) to table rows

=head2 no_mouseover

Valid in Configuration file: Yes

Turns off the mouseover feature on the table output by build_table

=head2 mouseover_class


Valid in Configuration file: Yes

The CSS class to use when mousing over a table row

=head2 searchable


Valid in Configuration file: Yes

Enables free form searching within a column

=head2 mouseover_bgcolor


Valid in Configuration file: Yes

Color for mouseover if not using a CSS definition. Defaults to red if not set

=head2 filtered_class

Valid in Configuration file: Yes

Defines the CSS class to use for columns that currently have an active Filter

=head2 ascending_string

Wants: string (can be image name)

Default to: '^'

Valid in Configuration file: Yes

The string used to represent the ascending sort filter option. If value ends
with a file extension assumes it is an image and adds approriate img tag.

=head2 descending_string

Wants: string (can be an image name)

Defaults to: 'v'

Valid in Configuration file: Yes

The string used to represent the descending sort filter option. If value ends
with a file extension assumes it is an image and adds approriate img tag.

=head2 rowclass_odd

Valid in Configuration file: Yes

The CSS class to use for odd rows within the table

=head2 navigation_separator

Valid in Configuration file: Yes

The seperator character(s) for string filter navigation

=head2 page_navigation_separator

Valid in Configuration file: Yes

The seperator for page navigation

=head2 table_field_name

(code ref || (like,only) , optional) - You can pass in anonymous subroutines for a particular field by using the table
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

sub create_auto_hidden_fields : Plugged {
    my ($self) = @_;
    my $hidden = $self->params() || {};
    my $hidden_options;
    foreach my $hidden_field ( keys %{ $hidden } ) {
            next if $hidden_field !~ /\w/;
            $hidden_options .=
qq!<input name="$hidden_field" type="hidden" value="$hidden->{$hidden_field}">!;
    }
    $self->auto_hidden_fields($hidden_options);
}

sub build_table : Plugged {
    my ( $self, %args ) = @_;
    
    my $table        = $args{-data_table}           || $self->data_table();
    if (!$table->isa( 'HTML::Table' ) ) {
         $table = HTML::Table->new();
    }
    my $table_obj      = $args{-pager_object}    || $self->pager_object();
    my $page_name      = $args{-page_name}       || $self->page_name();
    my $query_string   = $args{-query_string}    || $self->query_string();
    my $exclude        = $args{-exclude_columns} || $self->exclude_columns() || 0;
    my $where          = $args{-where}           || $self->where();
    my $order_by       = $args{-order_by}        || $self->order_by();
    my $filtered_class = $args{-filtered_class}  || 'filtered';
    my $search         = $args{-searchable}      || $self->searchable || 0;
    
    my $class;
    
    # order by via query string adjustment
    if ($query_string && $query_string =~ /ORDERBYCOL/) {
        my ($order_col,$direction) = $query_string =~ m/BYCOL\-([\w\_]+)=(\w+)/;
        $order_by = "$order_col $direction"; 
    }
    
    my @columns = $self->determine_columns($args{-display_columns});
    
    if ( !@columns ) {
        warn
          "Array 'columns' was not defined and could not be auto identified\n";
    }
    
    if ( $exclude eq 'ARRAY' ) {
        @columns = $self->_process_excludes( $exclude, @columns );
    }
   
    # create text search row if requested
    if ($search) {
        my @text_fields;
        $self->create_auto_hidden_fields();
        foreach my $col (@columns) {
	    push @text_fields , qq!
            <form method="GET" action="$page_name">
	    <input type="text" name="SEARCH-$col" value="" size="4">
	    <input type="submit" value="GO">! .
            $self->auto_hidden_fields() .
            qq!</form>
	    !;
	}

	$table->addRow(@text_fields);
	my $corner = $table->getCell( 1, 1 );
    }
    
    my @records;

    if ( ref $args{-records} eq 'ARRAY' ) {
        @records = @{ $args{-records} };
    }
    else {
	
        # testing based on suggestion from user
        
        if ( ref $where eq 'ARRAY' ) {
           @records = $table_obj->search_where( @{ $where } ); 
        }
    
        elsif ( ref $where ne 'HASH' ) {
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

    # define our background colors (even and odd rows)
    my $bgcolor   = $args{-rowcolor_odd}  || $self->rowcolor_odd()  || '#c0c0c0';
    my $bgcolor2  = $args{-rowcolor_even} || $self->rowcolor_even() || '#ffffff';
    
    # define our colors or classes
    my $mouseover_bgcolor = $args{-mouseover_bgcolor}  ||
                            $self->mouseover_bgcolor() ||
                            'red';
    
    my $mouseover_class   = $args{-mouseover_class}  ||
                            $self->mouseover_class() ||
                            '';
    
    # define if we use bgcolor or class to assign color
    my $js_this_object = 'this.bgColor';
    my $bg_over = $mouseover_bgcolor;
    my $bg_out_odd  = $bgcolor;
    my $bg_out_even = $bgcolor2;
    
    if ($mouseover_class) {
        $js_this_object = 'this.className';
        $bg_over = $mouseover_class;
	$args{-rowclass} ||= $self->rowclass() || 'defaultRowClass';
	$args{-rowclass_odd} ||= $self->rowclass_odd() || 'defaultRowClassOdd';
        $bg_out_even = $args{-rowclass};
	$bg_out_odd  = $args{-rowclass_odd};
    }


    
    foreach my $rec (@records) {
        $count++;
        my @row;
        foreach (@columns) {
            if (!defined $args{$_} && defined $self->{column_filters}{$_}) {
                $args{$_} = $self->{column_filters}{$_};
            }
            $self->output_debug_info( "col = $_" );
            if ( ref $args{$_} eq 'CODE' ) {
                push @row, $args{$_}->( 
		             $rec->$_,
			     $query_string
			     );
            }
            elsif ( $args{$_} =~ /only|like|beginswith|endswith|contains|variance/i ) {

                # || $args{$_} eq 'LIKE') {
                # send script, column, value, url
                push @row,
                  _value_link( $args{$_}, 
		               $page_name ,
			       $_,
			       $rec->$_,
			       $query_string );
            } elsif ( ref($args{$_}) eq 'ARRAY' ) {
	       my ($type,$value) = @{ $args{$_} };
	         my $display_value = $rec->$_;
	         push @row,
                  _value_link( "$type$value", 
		               $page_name ,
			       $_,
			       $display_value,
			       $query_string,
			       1 );
	       
	    }
            else {
                push @row, $rec->$_;

            }
	    
	    if ($query_string && $query_string =~ /(ONL|VAR|BEGIN|ENDS|CONTAINS)\w+\-$_/) {
	       $row[-1] = qq~<div class="$filtered_class">$row[-1]</div>~;
	    }
        }
        $table->addRow(@row);
	
	if ( ($count % 2 == 0) && $args{-rowclass} ne '' ) {
            $table->setRowClass( -1, $args{-rowclass} );
	} elsif ( ($count % 2 != 0) && $args{-rowclass} ne '' ) {
	    $table->setRowClass( -1, $args{-rowclass_odd} );
	} elsif ( ($count %2 == 0) && $args{-rowclass} eq '') {
	    
	    $table->setRowBGColor( -1, $bgcolor2 );
	    #$table->setRowAttr( -1 , 
	    #  qq!onmouseover="$js_this_object='$bg_over'"
	    #   onmouseout="$js_this_object='$bgcolor'"!);
	} elsif ( ($count %2 != 0) && $args{-rowclass} eq '') {
	    
	    $table->setRowBGColor( -1, $bgcolor );
	}
	
        $args{-no_mouseover} ||= $self->no_mouseover();
        
	if (!$args{-no_mouseover}) {
            
	     my $out;
	     if ($count % 2 == 0) {
	         $out = $bg_out_even;
	     } else {
	         $out = $bg_out_odd;
	     }
	        $table->setRowAttr( -1 , 
	          qq!onmouseover="$js_this_object='$bg_over'"
	          onmouseout="$js_this_object='$out'"!);
        }
	
	
	# if defined $args{-rowclass};
    }
    $self->data_table($table);
    return $table;
}

sub create_order_by_links : Plugged {
     my ($self,%args) = @_;
     my $query_string = $args{-query_string}      || $self->query_string();
     my $asc_string   = $args{-ascending_string}  || 'v';
     my $desc_string  = $args{-descending_string} || '^';
     my $page_name    = $args{-page_name}         || $self->page_name();
     my $q_string_copy = $query_string;
     $query_string =~ s/ORDERBYCOL-(\w+)\=(ASC|DESC)//;
     my $link_base    = "$page_name?$query_string&";
     
     my @order_by_html;
     foreach my $col ( @{$self->display_columns} ) {
         my $asc_qstring  = "ORDERBYCOL-$col=ASC";
	 my $desc_qstring = "ORDERBYCOL-$col=DESC";
	 my $asc_class_open   = '';
	 my $desc_class_open  = '';
	 my $asc_class_close  = '';
	 my $desc_class_close = '';
	 if ($q_string_copy =~ /\Q$asc_qstring/) {
	     $asc_qstring = '';
	     $asc_class_open = qq!<span class="orderedBy">!;
	     $asc_class_close = qq!</span>!;
	 }
	 
	 if ($q_string_copy =~ /\Q$desc_qstring/) {
	     $desc_qstring = '';
	     $desc_class_open = qq!<span class="orderedBy">!;
	     $desc_class_close = qq!</span>!;
	 }
	 
         if ($asc_string =~ /\.\w{3,}/i) {
            $asc_string = qq!<img src="$asc_string">!;  
         }
         
         if ($desc_string =~ /\.\w{3,}/i) {
            $desc_string = qq!<img src="$desc_string">!;  
         }
         
         
         push @order_by_html, qq!
         $asc_class_open<a href="$link_base$asc_qstring">$asc_string</a>$asc_class_close
	 $desc_class_open<a href="$link_base$desc_qstring">$desc_string</a>$desc_class_close
!; 
     }
     return @order_by_html;
}

# this is a work in progress
# intended to provide hidden field support
# for both forms and table

sub add_hidden : Plugged {
    
    my ($self,$args) = @_;
    my $hidden;
    my $html_table;
    if ( $hidden ) {
        my $corner = $html_table->getCell( 1, 1 );
        foreach my $hidden_field ( keys %{ $hidden } ) {
            next if $hidden_field !~ /\w/;
            $corner .=
qq!<input name="$hidden_field" type="hidden" value="$hidden->{$hidden_field}">!;
        }

        $html_table->setCell( 1, 1, $corner );
    }

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

=head2 no_submit

The submit button can be removed by sending -no_submit as an attribute to the build_form
method or by setting the no_submit tag to 1. Default is 0;

=head2 no_form_tag

The opening HTML form tag can be removed by sending -no_from_tag as an attribute
to the build_form method or by setting the no_form_tag method to 1. Default is 0;

    $html->no_form_tag(1);

=head2 hidden_fields

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

    $args{-no_submit} ||= $self->no_submit();

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

    $args{-no_form_tag} ||= $self->no_form_tag();

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
            $self->output_debug_info( "_process_attributes is doing a $_" );
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
    $self->output_debug_info( "excluding" . Dumper(\%exclude)  );
    map { undef $_ if exists $exclude{$_} } @columns;
    return grep /\w/, @columns;
}

sub _value_link {

    my ( $type, $page_name, $column, $name, $turl, $hardcoded ) = @_;
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
    
    if ( $type =~ /begin|end|contain/i && !$hardcoded ) {
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
	 &output_debug_info( "Just removed $otype" );
    }
        
    if ($add_item == 1) {
            $turl .= "&$type-$column=$link_val";
    }
 
       &output_debug_info( qq~<br>type: $type 
    <br> page: $page_name 
    <br> column: $column 
    <br> name: $name 
    <br> turl: $turl
    <br> ourl: $ourl
    <br>~ );
       
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
    my $page_navigation_separator = $args{-page_navigation_separator} ||
                                    $self->page_navigation_separator() ||
                                    ' | ';
    
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
            $nav_block .= $page_navigation_separator;
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

=head2 hide_zero_match

Removes items that have no matches in the database from the strings allowed in the final navigation.

-position (optional - default is 'begin') - Tells the method how to do the match, allowed options are any case
of 'begin' , 'end' or 'contains'.  These options can be the entire anchor points as outlined above,
but for ease of use only the aforemention is enforced at a code level.

=head2 query_string

(optional) - See methods above for documentation

=head2 navigation_list

(optional, array_ref - default is A-Z) - Array ref containing the strings to filter on.

=head2 navigation_column

Indicates which column the string filter will occur on.
If you want to provide a filter on multiple columns it is recommended that
you create multiple string_filter_navigation.
Can be set via method, string_filter_navigation argument or configuration file

-page_name - The name of page that the navigation should link to

=head2 navigation_alignment

Set HTML attribute alignment for the page navigation.

=head2 navigation_seperator

    $cdbi_html_table->navigation_seperator('::');
-or-
    -navigation_seperator => '::' # argument passed into string_filter_navigation
-or-
    navigation_sperator=:: in the configuration file
    
(optional, default two non-breaking spaces) - The characters to place between each item in the list.

=head2 align

(optional, defaults to center) - defines the alignment of the navigation

=head2 no_reset

don't include the filter reset link in the output

=head2 form_select

this methods expects the following:

    -value_column    # column containing the value for the option in the select
    -text_column     # column containing the text for the optoin in the select (optional)
    -selected_value  # the value to be selected (optional)
    -no_select_tag   # returns option list only (optional)

=head1 FILTERS

Filters are generated with the build_table method.  Filters allow for cascading
drill down of data based on individual cell values.  See Example page for
a demo.

=head2 beginswith

Declare a begins with match on a column

    $cdbi_html_table->beginswith('column_name','A');
    # where 'A' is the value to match at the beginning

=head2 endswith

   $cdbi_html_table->endswith('column_name','A');
   # where 'A' is the value to match at the end of the column contents

=head2 contains

   $cdbi_html_table->contains('column_name','A');
   # where 'A' is the value to match anywhere in the column contents

=head2 variancepercent

   $cdbi_html_table->variancepercent('column_name',2);
   # where '2' is the allowed percentage of variance to filter on

=head2 variancenumerical

   $cdbi_html_table->variancenumerical('column_name',2);
   # where '2' is the allowed variance to filter on based
   # if value for 'column_name' is clicked

=head2 only

    $cdbi_html_table->only('column_name');
    # creates a filter on 'column_name' cells to match the value in the cell
    # clicked

=cut

sub string_filter_navigation : Plugged {

    # intent of sub is to provide a consistent way to navigate to find
    # records that contain a particular string.
    my ( $self, %args ) = @_;

    # set up or variables and defaults

    my @links;

    my @alphabet;

    $args{-strings} = $args{-navigation_list} || $self->navigation_list();

    if (ref($args{-strings}) eq 'ARRAY') {
        @alphabet = @{ $args{-strings} }
    } else {
        @alphabet = ( 'A' .. 'Z' )
    }

    my $navigation_separator = $args{-navigation_separator} ||
                               $self->navigation_separator()  ||
                               '&nbsp;&nbsp;';
                               
    my $navigation_alignment = $args{-navigation_alignment}
                               || $self->navigation_alignment()
                               || 'center';
                               
    my $page_name      = $args{-page_name}       || $self->page_name();
    my $query_string   = $args{-query_string}    || $self->query_string();
    my $filtered_class =    $args{-filtered_class}
                            || $self->filtered_class()
                            || 'filtered';
    
    $args{-no_reset} ||= $self->no_reset();
    
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

        if ($query_string =~ /(WITH|CONTAINS)$string\-$args{-column}/) {
	       $links[-1] = qq~<span class="$filtered_class">$links[-1]</span>~;
	}

    }
    
    return qq!<div align="$navigation_alignment">!
      . join( $navigation_separator, @links )
      . "</div>";
}

sub search_ref : Plugged {
    my ( $self, %args ) = @_;
    $args{-exclude_from_url} ||= $self->exclude_from_url();
    $args{-params} ||= $self->params();
    my %where;
    if ( exists $args{-exclude_from_url} ) {

        # print_arrayref("Exclude from URL",$args{-exclude_from_url});
        map { delete $args{-params}->{$_} } @{ $args{-exclude_from_url} };
    }

    if ( exists $args{-params} ) {

        # print_hashref("Incoming parameters",$args{-params});
        my @only       = grep /ONLY\-/,               keys %{ $args{-params} };
        my @like       = grep /LIKE\-/,               keys %{ $args{-params} };
        my @beginswith = grep /BEGINSWITH\w+/,        keys %{ $args{-params} };
        my @endswith   = grep /ENDSWITH\w+/,          keys %{ $args{-params} };
        my @contains   = grep /CONTAINS[\@\w+]/,      keys %{ $args{-params} };
        my @percentage = grep /VARIANCEPERCENT\d+/,   keys %{ $args{-params} };
        my @numerical  = grep /VARIANCENUMERICAL\d+/, keys %{ $args{-params} };
	
        if (@only) {
            $self->output_debug_info( "\tOnly show matches of: " );
            foreach my $only (@only) {
	        $self->output_debug_info( $only );
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
            $self->output_debug_info( "\tShow only begining with" );
            foreach my $beginswith (@beginswith) {
                my ( $value, $column ) =
                  $beginswith =~ m/beginswith(\w+)-([\w\_]+)/i;
                $self->output_debug_info(
            qq~    '$beginswith' - looking $column that begins with $value~);
                $where{$column} = { 'LIKE', "$value\%" };
            }
        }

        if (@endswith) {
            $self->output_debug_info("\tShow only endswith with");
            
            foreach my $endswith (@endswith) {
                my ( $value, $column ) =
                  $endswith =~ m/endswith(\w+)-([\w\_]+)/i;
                $self->output_debug_info(
                  qq~\t\t'$endswith' - looking $column that ends with $value~);
                $where{$column} = { 'LIKE', "\%$value" };
            }
        }

        if (@contains) {
            $self->output_debug_info("\tShow only entries that contain");
            my $null = 'IS NULL';
            my $notnull = 'IS NOT NULL';
            foreach my $contains (@contains) {
                my ( $value, $column ) =
                  $contains =~ m/contains(.+)-([\w\_]+)/i;
                $self->output_debug_info(
                    qq~\t\t'$contains' - looking $column that contain $value~);
                if ($value eq 'NOTNULL') {
                     $where{$column} = \$notnull;
                } elsif ($value eq 'NULL') {
                     $where{$column} = \$null;
                } elsif ($value eq 'NOSTRING') {
                     $where{$column} = '';
                } else {
                     $where{$column} = { 'LIKE', "\%$value\%" };
                }
            }
        }

	if (@percentage) {
	    $self->output_debug_info(
                "\tShow only entries that are within a percentage variance");
	    foreach my $per (@percentage) {
	        my ( $percent , $column ) =
		   # VARIANCEPERCENT5-wt=170
		   $per =~ m/VARIANCEPERCENT(\d+)-([\w\_]+)/i;
		   # $per =~ m/VARIANCEPERCENT(\d+)-([\w\_]+)/i;
		my $value = $args{-params}->{$per};
	        $self->output_debug_info(
                 qq~    $per - looking for $percent variance
    on $column where value for variance is $value~);
		$percent = $percent / 100;
		my $diff    = $value * $percent;
		
		my $high = $value + $diff;
		my $low  = $value - $diff;
		
		$where{$column} = { 'BETWEEN' , [ $low , $high ] };
	    }
	}
	
	if (@numerical) {
	    $self->output_debug_info("\tShow only entries that are within a percentage variance");
	    foreach my $string (@numerical) {
	        my ( $number , $column ) =
		   # VARIANCEPERCENT5-wt=170
		   $string =~ m/VARIANCENUMERICAL(\d+)-([\w\_]+)/i;
		   # $per =~ m/VARIANCEPERCENT(\d+)-([\w\_]+)/i;
		my $value = $args{-params}->{$string};
	        $self->output_debug_info(
    qq~    $string - looking for $number variance
    on $column where value for variance is $value~);
		
		
		my $high = $value + $number;
		my $low  = $value - $number;
		
		$where{$column} = { 'BETWEEN' , [ $low , $high ] };
	    }
	}
	
    }

    if (exists $args{-override}) {
        %where = ( %where , %{  $args{-override} } );
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

        if ( $key =~ m/\w/ && defined $Param{"$key"} ) {
            $self->output_debug_info("url_query $key<br>");
            push @url, qq~$key=~ . uri_escape( $Param{"$key"} )
              if defined $Param{"$key"}; # ne '';
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
    &output_debug_info( Dumper($table_obj) );
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

=head1 INTERNAL METHODS/SUBS

If you want to change behaviors or hack the source these methods are subs should
be reviewed as well.

=head2 get_records

Finds all matching records in the database

=head2 create_order_by_links

=head2 add_number

=head2 determine_columns

Finds the columns that are to be displayed

=head2 auto_hidden_fields

=head2 add_hidden

=head2 create_auto_hidden_fields

=head1 BUGS

Unknown at this time.

=head1 SEE ALSO

L<Class::DBI>, L<Class::DBI::AbstractSearch>, L<Class::DBI::AsForm>, L<HTML::Table>, L<Class::DBI::Pager>

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


sub params : Plugged {
      my $self = shift;

      if(@_ == 1) {
          my $params = shift;
          foreach my $key ( keys %{ $params } ) {
              next if $key !~ /SEARCH/;
              if (!defined $params->{$key}) {
                  delete $params->{$key};
                  next;
              }
              my ($column) = $key =~ /SEARCH-(.+)/;
              $params->{"CONTAINS$params->{$key}-$column"} = 1;
              delete $params->{$key};
          }
          $self->{params} = $params;
      }
      elsif(@_ > 1) {
          $self->{params} = [@_];
      }

      return $self->{params};
  }


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

## Testing this section for .9 release

sub config : Plugged {
    my ($self,$key) = @_;
    # my $config = Class::DBI::Plugin::HTML::Config->new();
    return $config_hash->{$key};
}

## the following are called with:
## $html->beginswith('lastname','A');

sub beginswith : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = [ 'BEGINSWITH' , $_[1] ];
}

sub endswith : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = [ 'ENDSWITH' , $_[1] ];
}

sub contains : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = [ 'CONTAINS' , $_[1] ];    
}

sub variancepercent : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = [ 'VARIANCEPERCENT' , $_[1] ];    
}

sub variancenumerical : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = [ 'VARIANCENUMERICAL' , $_[1] ];    
}

sub only : Plugged {
    my $self = shift;
    $self->{column_filters}{$_[0]} = 'ONLY';
}

## from config

sub rows : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{rows} = shift;
    }
    elsif(@_ > 1) {
        $self->{rows} = [@_];
    }
    return $self->{rows};
}

sub exclude_from_url : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{exclude_from_url} = shift;
    }
    elsif(@_ > 1) {
        $self->{exclude_from_url} = [@_];
    }
    return $self->{exclude_from_url};
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

sub descending_string : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{descending_string} = shift;
    }
    elsif(@_ > 1) {
        $self->{descending_string} = [@_];
    }
    return $self->{descending_string};
}

sub ascending_string : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{ascending_string} = shift;
    }
    elsif(@_ > 1) {
        $self->{ascending_string} = [@_];
    }
    return $self->{ascending_string};
}

sub mouseover_bgcolor : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{mouseover_bgcolor} = shift;
    }
    elsif(@_ > 1) {
        $self->{mouseover_bgcolor} = [@_];
    }
    return $self->{mouseover_bgcolor};
}

sub mouseover_class : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{mouseover_class} = shift;
    }
    elsif(@_ > 1) {
        $self->{mouseover_class} = [@_];
    }
    return $self->{mouseover_class};
}

sub no_form_tag : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{no_form_tag} = shift;
    }
    elsif(@_ > 1) {
        $self->{no_form_tag} = [@_];
    }
    return $self->{no_form_tag};
}

sub no_mouseover : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{no_mouseover} = shift;
    }
    elsif(@_ > 1) {
        $self->{no_mouseover} = [@_];
    }
    return $self->{no_mouseover};
}

sub no_reset : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{no_reset} = shift;
    }
    elsif(@_ > 1) {
        $self->{no_reset} = [@_];
    }
    return $self->{no_reset};
}

sub no_submit : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{no_submit} = shift;
    }
    elsif(@_ > 1) {
        $self->{no_submit} = [@_];
    }
    return $self->{no_submit};
}

sub debug : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{debug} = shift;
    }
    elsif(@_ > 1) {
        $self->{debug} = [@_];
    }
    return $self->{debug};
}

sub searchable : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{searchable} = shift;
    }
    elsif(@_ > 1) {
        $self->{searchable} = [@_];
    }
    return $self->{searchable};
}

sub rowclass : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{rowclass} = shift;
    }
    elsif(@_ > 1) {
        $self->{rowclass} = [@_];
    }
    return $self->{rowclass};
}

sub rowclass_odd : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{rowclass_odd} = shift;
    }
    elsif(@_ > 1) {
        $self->{rowclass_odd} = [@_];
    }
    return $self->{rowclass_odd};
}

sub rowcolor_even : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{rowcolor_even} = shift;
    }
    elsif(@_ > 1) {
        $self->{rowcolor} = [@_];
    }
    return $self->{rowcolor_even};
}

sub rowcolor_odd : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{rowcolor_odd} = shift;
    }
    elsif(@_ > 1) {
        $self->{rowcolor_odd} = [@_];
    }
    return $self->{rowcolor_odd};
}

sub filtered_class : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{filtered_class} = shift;
    }
    elsif(@_ > 1) {
        $self->{filtered_class} = [@_];
    }
    return $self->{filtered_class};
}

sub navigation_list : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{navigation_list} = shift;
    }
    elsif(@_ > 1) {
        $self->{navigation_list} = [@_];
    }
    return $self->{navigation_list};
}

sub navigation_column : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{navigation_column} = shift;
    }
    elsif(@_ > 1) {
        $self->{navigation_column} = [@_];
    }
    return $self->{navigation_column};
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

sub navigation_alignment : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{navigation_alignment} = shift;
    }
    elsif(@_ > 1) {
        $self->{navigation_alignment} = [@_];
    }
    return $self->{navigation_alignment};
}

#sub separator : Plugged {
#    my $self = shift;
#
#    if(@_ == 1) {
#        $self->{separator} = shift;
#    }
#    elsif(@_ > 1) {
#        $self->{separator} = [@_];
#    }
#    return $self->{separator};
#}

sub hide_zero_match : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{hide_zero_match} = shift;
    }
    elsif(@_ > 1) {
        $self->{hide_zero_match} = [@_];
    }
    return $self->{hide_zero_match};
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

sub auto_hidden_fields : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{auto_hidden_fields} = shift;
    }
    elsif(@_ > 1) {
        $self->{auto_hidden_fields} = [@_];
    }
    return $self->{auto_hidden_fields};
}

sub config_file : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{config_file} = shift;
    }
    elsif(@_ > 1) {
        $self->{config_file} = [@_];
    }
    return $self->{config_file};
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


sub page_navigation_separator : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{page_navigation_separator} = shift;
    }
    elsif(@_ > 1) {
        $self->{page_navigation_separator} = [@_];
    }
    return $self->{page_navigation_separator};
}

sub navigation_separator : Plugged {
    my $self = shift;

    if(@_ == 1) {
        $self->{navigation_separator} = shift;
    }
    elsif(@_ > 1) {
        $self->{navigation_separator} = [@_];
    }
    return $self->{navigation_separator};
}


## end from config

1;
