package Class::DBI::Plugin::HTML;

use base 'Class::DBI::Plugin';

our $VERSION = 0.7;
use HTML::Table;
use HTML::FillInForm;
use CGI qw/:form/;
use Class::DBI::AsForm;
use Data::Dumper;
use URI::Escape;
use strict;

our $debug = 0;

=head1 NAME

Class::DBI::Plugin::HTML - Generate HTML Tables and Forms in conjunction with Class::DBI

=head1 SYNOPSIS

 # Inside of your sub-class of Class::DBI add this line:
 use Class::DBI::Plugin::HTML;
   
 # if you want to use the pager function you will need to
 use Class::DBI::Pager; # as well
   
 .....
   
 # Inside your script you will be able to use this modules
 # methods on your table class or object as needed.
   
 my $pager = Table::User->pager(20, $cgi->param('page') || 1);

 my $html_table = Table::User->html_table(-align=>'center');

 $html_table->addRow('User Name','First Name','Last Name');
 
 my %params;

 map { $params{$_} = 
        uri_unescape($cgi->param("$_"))
    } $cgi->param();

 my ($where) = Table::User->search_ref( 
       -params => \%params,
       -like_column_map  => { email => 'sam%' }
 );
 
 my ($url_query) = Table::User->url_query(
      -params => $params,
      -exclude_from_url => [ 'page' ],
 );
 
 my $table = Table::User->build_table(
      -pager   => $pager,
      -columns => [ 'user_name','first_name','last_name' ],
      -exclude => [ 'created_on' , 'modified_on' ],
      -table   => $html_table,
      -where   => $where,
      -query_string     => $url_query,
      
      user_id => sub {
          return qq!<a href="show.pl?$url_query&id=! . shift() . qq!">view</a>!  
     }, );

 my $nav = Table::User->html_table_navigation(
     -pager        => $pager,
     -navigation   => 'next',
     -page_name     => 'test2.pl',
     -query_string => $url_query,
 );

 print "'$nav'\n";

 Table::User->add_bottom_span($table,$nav);
     
 print $table;

 my $user = Table::User->retrieve(1);

 #my $form = Table::User->build_form(

 # OR if you want to use the data record to fill in the form
 # make the form via a object versus the class.

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
    ignore_fields => $ignore
 );

=head1 DESCRIPTION

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
If you are looking for a framework based on Class::DBI I suggest yoy
look into the Maypole module.


=head1 FilterOnClick

The reason for this module is to provide a generic method
of a technique I codifed in 2000 inside some one off CGI
scripts.  That technique within its problem space produced a
significantly easier to navigate database record view/action
system for those that used it.  While the current status 
(version .6 at the time of this writing) isn't a complete
representation of the tool, I hope that it will provide enough
so that others can contribute their ideas on how to improve the
design and make it more generic.

The concept, at its core, is relatively simple in nature.
You get a table of records, for our example lets assume we
have four columns: "First Name" aka FN, "Last Name" aka LN , "Address" ,
"Email".  The FN , LN and Email address are links back to the
script that generated the original table.  The link holds information
that will modify the query.  The link can be set to "LIKE" or "ONLY".
"ONLY" is an "=" in the SQL statement, the where clause that is 
created within the module automatically is passed through to the
Class::DBI::AbstractSearch module, which is in turn based on the
SQL::Abstract module.  The "LIKE" is a little more complicated (confusing?)
in its setup.  The actual like statement is mapped within the code
rather then inside of the link, this is most likely inadequate, but
made sense at the time.

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

Currently there are two built in FilterOnClick utilties, ONLY and LIKE,
see documention for build_table for more inoformation on using them.

=head1 METHOD NOTES

The parameters are passed in via a hash for most of the methods,
the Class::DBI::Plugin::HTML specific keys in the hash are preceeded
by a hypen (-).  Column names can be passed in with there own
anonymous subroutine (callback) if you needed to produce any
special formating or linkage.

=head1 METHODS

=cut

=head2 html_table

returns an HTML::Table object, this is a public method and accepts a hash as its
constructor options.  See HTML::Table for valid arguments.

=cut

sub html_table : Plugged {
    my ( $self, %args ) = @_;
    return HTML::Table->new(%args);
}

=head2 build_table

Accepts a hash of options to define the table parameters and content.  This method
returns an HTML::Table object.
   
   my $table = Table::User->build_table(
   # pass in the Class::DBI::Pager object if applicable
   -pager   => $pager,
   
   # define the columns (this is also the order)
   -columns => [ 'user_name','first_name','last_name' ],
                
   # what columns not to show, useful if you are dynamically
   # turning off columns and don't want to alter the columns
   # list at the page/script level for whatever reason
   -exclude => [ 'created_on' , 'modified_on' ],
                
   # can pass in an existing HTML::Table object, this
   # allows for the header to be assigned etc. prior to
   # dynamically adding the records from the database
   -table   => $html_table,
                
   # using the column name as the key you can pass in
   # sub routines to dynamically alter the way the column             
   # is displayed 
   user_id => sub {    return qq!<a href="show.htm?id=! . shift() . qq!">view</a>!   },

   ):

The build_table method has a wide range of paramters that are mostly optional.

-columns (array ref, optional) - The list of field names you want to create the
columns from. If not sent the order the fields in the database will
appear will be inconsistent.

-exclude (array ref, optional) - Don't show these fields even if included in the columns.
Useful if you are not setting the columns or the columns are dynamic and you
want to insure a particular column (field) is not revealed.

-table (HTML::Table Object, optional) - Allows for you to pass in an HTML::Table object, this is handy
if you have setup the column headers or have done some special formating prior to
retrieving the results.   

-pager (Class::DBI::Pager Object, optional) - Allows you to pass in a Class::DBI::Pager based object. This is useful in conjunction with the html_table_navigation method.  If not passed in
and no -records have been based it will use the calling class to perform the
lookup of records.

-records (array ref, optional) - Expects an anonymous array of record objects. This allows for
your own creation of record retrieval methods without relying on the underlying techniques
of the build_table attempts to automate it.

-where (Hash Ref, optional) - Expects an anonymous hash that is compatiable with Class::DBI::AbstractSearch The url_and_where_statement method possibly can help
you dynamically create these.

-order (scalar, optional) - This is passed along with the -where OR it is sent to the retrieve_all_sort_by method if present.  The retrieve_all_sort_by method is part of the Class::DBI::Plugin::RetrieveAll module.

-page_name (scalar) - Used to create the links for the built in 'ONLY' and 'LIKE' utilities

-url (scalar, optional) - passed to the anonymous subroutines that might be available for a particular column.

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

Optionally you can use the built FilterOnClick utilities of 'ONLY' and 'LIKE'.
The example above is the base of the process, but is provided as a built in accessible by
using:

   first_name => 'only',

The 'only' can could be  replaced with 'like' and is case insensitive.

NOTE: If you use 'like' you will need to have a proper -like_column_map hashref
assigned in your search_ref call.


=cut

sub build_table : Plugged {
    my ( $self, %args ) = @_;
    
    # print $args{-table} , "\n";
    my $table = $args{-table} || $self->html_table();

    my $table_obj = $args{-pager} || $self;
    my @columns = @{ $args{-columns} };
    if ( !@columns ) { @columns = $self->columns(); }
    print Dumper( \@columns ) if $debug;

    if ( !@columns ) {
        warn
          "Array 'columns' was not defined and could not be auto identified\n";
    }

    if ( ref $args{-exclude} eq 'ARRAY' ) {
        @columns = $self->_process_excludes( $args{-exclude}, @columns );
    }
    my @records;

    if ( ref $args{-records} eq 'ARRAY' ) {
        @records = @{ $args{-records} };
    }
    else {

        if ( ref $args{-where} ne 'HASH' ) {
            if ( defined $args{-order} ) {
                @records = $table_obj->retrieve_all_sorted_by( $args{-order} );
            }
            else {
                @records = $table_obj->retrieve_all;
            }

# @records = $table_obj->search( user_id => '>0' , { order_by => $args{-order} } );
        }
        else {

            # my %attr = $args{-order};
            @records =
              $table_obj->search_where( $args{-where},
                { order => $args{-order} } );
        }

    }
    foreach my $rec (@records) {
        my @row;
        foreach (@columns) {

            print "col = $_\n" if $debug;
            if ( ref $args{$_} eq 'CODE' ) {
                push @row, $args{$_}->( $rec->$_, $args{-query_string} );
            }
            elsif ( $args{$_} =~ /only|like|beginswith|endswith|contains/i ) {

                # || $args{$_} eq 'LIKE') {
                # send script, column, value, url
                push @row,
                  _value_link( $args{$_}, $args{-page_name}, $_, $rec->$_,
                    $args{-query_string} );
            }
            else {
                push @row, $rec->$_;

            }
        }
        $table->addRow(@row);
        $table->setRowClass( -1, $args{-rowclass} ) if defined $args{-rowclass};
    }
    return $table;
}

=head2 build_form

Accepts a hash of options to define the form options.  Values can be left blank for the
value on keys in form element names if you want to use the form fill in technique described
in this document.

    my $form = Table::User->build_form(
       # assign attributes of the form tag (optional)
       -form_tag_attributes => { enctype => 'multipart/form-data' },
       -columns => [ 'user_name','first_name','last_name' ],
       -exclude => [ 'user_id' , 'created_on' , 'modified_on' ],
       
       # add hidden tags to bottom of form, these values are put
       # into the first cell of the table
       -hidden => { 'user_id' => '' },
       
       # assign the friendly name for the cell with the form
       # element name
       -label   => { user_name => 'User Name' },
       
       # same as the build_table method, this allows for custom
       # handling of a specific field based on the column name
       user_name => sub { 
               return shift() . qq! <a href="view.pl">view</a>! },
     );
     
     print $form;

=cut

sub build_form : Plugged {

    my ( $self, %args ) = @_;

    #my %args = %{$targs};
    #undef($targs);
    my $html_table = $args{-table} || HTML::Table->new();
    my @columns;
    if ( ref $args{-columns} eq 'ARRAY' ) {
        @columns = @{ $args{-columns} };
    }
    else {
        @columns = $self->columns if !@columns;
    }
    if ( !@columns ) {
        warn
          "Array 'columns' was not defined and could not be auto identified\n";
    }
    if ( ref $args{-exclude} eq 'ARRAY' ) {
        @columns = $self->_process_excludes( $args{-exclude}, @columns );
    }

    my %cgi_field = $self->to_cgi;

    foreach my $col (@columns) {
        my $cell_content;
        if ( ref $args{$col} eq 'CODE' ) {
            $cell_content = $args{$col}->( $cgi_field{$col}->as_HTML() );
        }
        else {

            # warn "$col\n";
            $cell_content = $cgi_field{$col}->as_HTML();
        }

        $html_table->addRow( $args{-label}->{$col} || $col, $cell_content );
        $html_table->setRowClass( -1, $args{-rowclass} )
          if defined $args{-rowclass};
    }

    if ( !$args{no_submit} ) {
        $html_table =
          $self->_process_attributes( $args{-attributes}, $html_table );
        $html_table->addRow();
        $html_table->setCellColSpan( $html_table->getTableRows, 1,
            $html_table->getTableCols );
        $html_table->setCell( $html_table->getTableRows, 1,
            CGI::submit( '.submit', 'Continue' ) );
    }

    if ( $args{-hidden} ) {
        my $corner = $html_table->getCell( 1, 1 );
        foreach my $hidden_field ( %{ $args{-hidden} } ) {
            next if $hidden_field !~ /\w/;
            $corner .=
qq!<input name="$hidden_field" type="hidden" value="$args{-hidden}{$hidden_field}">!;
        }

        $html_table->setCell( 1, 1, $corner );
    }

    if ( !$args{no_form_tag} ) {
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
    $type = uc($type);
    if ( $turl =~ /$type\-$column=/ ) {
        $turl =~ s/$type\-$column=[\w\-\_]+//;
    }
    else {
        my $link_val = $name;

        # get rid of the past filter on position (begin,end,contains)

        if ( $turl =~ /$type\w+\-$column=/ ) {
            $turl =~ s/$type\w+\-$column=1//;
        }

        $link_val = 1 if $type =~ /like|begin|end|contain/i;
        if ( $type =~ /begin|end|contain/i ) {
            $type .= $name;
        }

        $turl .= "&$type-$column=$link_val";
    }
    return qq!<a href="$page_name?$turl">$name</a>!;

}

=head2 html_table_navigation

Creates HTML anchor tag (link) based navigation for datasets. Requires Class::DBI::Pager.
Navigation can be in google style (1 2 3 4) or block (previous,next).

    my $nav = Table::User->html_table_navigation(
                        -pager        => $pager,
                        # pass in -navigation with block as the value for
                        # next/previous style 
                        # "google" style is the default
                        -navigation   => 'block',
                        -page_name     => 'test2.pl', 
                   );

    print "'$nav'\n";

=cut

sub html_table_navigation : Plugged {
    my ( $self, %args ) = @_;
    my $pager = $args{-pager};

    my $nav_block;
    my $nav_number;
    if (   defined $args{-navigation}
        && defined $args{-page_name} )
    {

        #if ( lc($args{-navigation}) eq 'block' ) {

        if ( $pager->previous_page ) {
            $nav_block .= CGI::a(
                {
                        href => "$args{-page_name}?page="
                      . $pager->previous_page . '&'
                      . $args{-query_string}
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
                        href => "$args{-page_name}?page="
                      . $pager->next_page . '&'
                      . $args{-query_string}
                },
                'next'
            );
        }

        #} else {
        foreach my $num ( $pager->first_page .. $pager->last_page ) {
            if ( $num == $pager->current_page ) {
                $nav_number .= "[ $num ]";
            }
            else {
                $nav_number .= '[ ';
                $nav_number .= CGI::a(
                    {
                        href =>
                          "$args{-page_name}?page=$num&$args{-query_string}"
                    },
                    $num
                );
                $nav_number .= ' ]';
            }
            $nav_number .= ' ';
        }

        #}
    }

    $nav_number = '' if $nav_number =~ /\[ 1 \]\s$/;

    my $nav = $nav_number;

    # warn "'$nav_number'\n";

    if ( lc( $args{-navigation} ) eq 'both' ) {
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

    if ( $args{-navigation} eq 'block' ) {
        $nav = $nav_block;
    }

    return $nav;
}

=head2 fill_in_form

Wrapper method for HTML::FillInForm, pass the arguments you would normally
pass into HTML::FillInForm.

    my $params = { user_name => 'trs80', first_name => 'TRS' };
    my $ignore = [ 'last_name' ];

    print Table::User->fill_in_form(
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
    my ( $self, $table, $add ) = @_;
    $table->addRow();
    $table->setCellColSpan( $table->getTableRows, 1, $table->getTableCols );
    $table->setCell( $table->getTableRows, 1, $add );
    return $table;
}

=head2 search_ref

Creates the URL and where statement based on the parameters based
into the script.

   my ($where) = Table::User->search_ref( 
           # hash ref of incoming parameters (form data or query string)
           -params => \%params,
          
            # the like parameters by column (field) name that the
	    # SQL statement should include in the where statement
           -like_column_map  => { 'first_name' => 'A%' },

           
   );

=head2 url_query

Creates the query portion of the URL based on the incoming parameters

    my ($url) = Table::User->url_query(
        
	# pass in the parameters coming into the script as a hashref 
	-params => \%params,
	
        # items to remove from the url, extra data that
        # doesn't apply to the database fields
        -exclude_from_url => [ 'page' ], 
    );

=head2 string_filter_navigation

    my ($filter_navigation) = Table::User(
       
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

    if ( $args{-no_reset} == 0 ) {
        push @links, qq!<a href="$args{-page_name}">Reset</a>$args{-separator}!;
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

        my @objects = $self->search_like(
            $args{-column} => "$filter",

            # { order_by => 'last_name' }
        );

        if (@objects) {

# send script, column, value, url
# push @row, _value_link($args{$_},$args{-page_name},$_,$rec->$_,$args{-query_string});
# ($type,$page_name,$column,$name,$turl)
            push @links,
              _value_link( $link_text, $args{-page_name}, $args{-column},
                $string, $args{-query_string} );

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
    if ( exists $args{-columns} ) {

        # print_arrayref("Columns",$args{-columns});

    }

    if ( exists $args{-table_rows} ) {

        # print "\nTable rows = $args{-table_rows}\n\n";
    }
    if ( scalar( keys %where ) > 0 ) {
        return \%where;
    }
    else {
        return undef;
    }

}

sub url_query : Plugged {
    my ( $self, %args ) = @_;
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
        return join( '&', @url );
    }
    else {
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
    warn Dumper($table_obj) if $debug;
    my @records;
    if ( ref $args{-where} ne 'HASH' ) {
        if ( defined $args{-order} ) {
            @records = $table_obj->retrieve_all_sorted_by( $args{-order} );
        }
        else {
            @records = $table_obj->retrieve_all;
        }

# @records = $table_obj->search( user_id => '>0' , { order_by => $args{-order} } );
    }
    else {

        # my %attr = $args{-order};
        @records =
          $table_obj->search_where( $args{-where}, { order => $args{-order} } );
    }
    return @records;
}

=head2 form_select
    
this methods expects the following:
    -value_column    # column containing the value for the option in the select
    -text_column     # column containing the text for the optoin in the select (optional)
    -selected_value  # the value to be selected (optional)
    -no_select_tag   # returns option list only

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

1;
