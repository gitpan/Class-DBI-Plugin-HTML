package Class::DBI::Plugin::HTML;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( 
                  html_table 
		  build_form
		  html_table_navigation
		  build_table
		  add_bottom_span
		  _process_excludes
		  _process_attributes
		  fill_in_form
		   );

our $VERSION = 0.5;		   
use HTML::Table;
use HTML::FillInForm;
use CGI qw/:form/;
use Class::DBI::AsForm;
use Data::Dumper;

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
     -navigation   => 'next',
     -page_url     => 'render_test.pl',
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

The intention of this module is to simply the creation of HTML 
tables and forms without having to write the HTML, either in your 
script or in templates.

This module is still in a pre-release state and using it for
anything other then evalution/development is not recommended.

Feedback on this module, its interface, usage, documentation etc. is
welcome.

The use of HTML::Table was selected because it allows for several
advanced sorting techniques that can provide for easy manipulation
of the data outside of the SQL statement.  This is very useful in
scenarios where you want to provide/test a sort routine and not write
SQL for it.

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

sub html_table {
    my ($self,%args) = @_;
    return HTML::Table->new(%args);
}

=head2 build_table

Accepts a hash of options to define the table parameters and content.
   
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

=cut



sub build_table {
    my ($self,%args) = @_;
    my ($table_obj,@columns);
    # print $args{-table} , "\n";
    my $table = $args{-table} || $self->html_table();
    
    my $table_obj = $args{-pager} || $self;
    @columns = @{ $args{-columns} }; 
    if (!@columns) { @columns = $self->columns(); }
    print Dumper(\@columns) if $debug;

    if (!@columns) {
       warn "Array 'columns' was not defined and could not be auto identified\n";
    }
    
    if (ref $args{-exclude} eq 'ARRAY') {
        @columns = $self->_process_excludes($args{-exclude},@columns);
    }
    
    my @records = $table_obj->retrieve_all;
    foreach my $rec (@records) {
        my @row;
        foreach (@columns) {
	
	print "col = $_\n" if $debug;
             if (ref $args{$_} eq 'CODE') {
                 push @row, $args{$_}->($rec->$_);
             } else {
                 push @row, $rec->$_;

             }
        }
        $table->addRow( @row );
    }
    return $table;
}

=head2 build_form

Accepts a hash of options to define the form options

    my $form = Table::User->build_form(
                
       -columns => [ 'user_name','first_name','last_name' ],
       -exclude => [ 'user_id' , 'created_on' , 'modified_on' ],
       
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
     
sub build_form {

    my ($self,%args) = @_;
    
    my $html_table = $args{-table} || HTML::Table->new();
    my @columns;
    if (ref $args{-columns} eq 'ARRAY') {
        @columns = @{ $args{-columns} };
    } else {
        @columns = $self->columns if !@columns;
    }
    if (!@columns) {
       warn "Array 'columns' was not defined and could not be auto identified\n";
    }
    if (ref $args{-exclude} eq 'ARRAY') {
        @columns = $self->_process_excludes($args{-exclude},@columns);
    }

    my %cgi_field = $self->to_cgi;

    foreach my $col (@columns) {
        my $cell_content;
        if (ref $args{$col} eq 'CODE') {
	    $cell_content = $args{$col}->($cgi_field{$col}->as_HTML());
	} else {
	    $cell_content = $cgi_field{$col}->as_HTML();
	}
	
        $html_table->addRow( 
	    $args{-label}->{$col} || $col ,
	    $cell_content
	);
    }
    
    if (!$args{no_submit}) {
        $html_table = $self->_process_attributes($args{-attributes},$html_table);
        $html_table->addRow( );
        $html_table->setCellColSpan( $html_table->getTableRows, 1 , $html_table->getTableCols  );
        $html_table->setCell($html_table->getTableRows, 1 , CGI::submit('.submit' , 'Continue') );
    }
    
    if (!$args{no_form_tag}) {
         $html_table = start_form . $html_table . end_form;
    }
   
    return $html_table;

}

sub _process_attributes {
    my ($self,$attributes,$html_table) = @_;
    foreach ( keys %{$attributes} ) {
        if (ref $attributes->{$_} eq 'ARRAY') { 
            print "doing a $_\n" if $debug; 
            $html_table->$_( @{ $attributes->{$_} }  );
        } else {
            $html_table->$_($attributes->{$_});
        }
    }
    return $html_table;
}

sub _process_excludes {
    my ($self,$exclude_list,@columns) = @_;
    my %exclude;
    map { $exclude{$_} = 1 } @{ $exclude_list };
    print "excluding\n" if $debug;
    map { undef $_ if exists $exclude{$_} } @columns;
    return grep /\w/ , @columns;
}

=head2 html_table_navigation

Creates HTML anchor tag (link) based navigation for datasets. Requires Class::DBI::Pager.
Navigation can be in google style (1 2 3 4) or block (previous,next).

    my $nav = Table::User->html_table_navigation(
                                -pager        => $pager,
                                -navigation   => 'next',
                                -page_url     => 'render_test.pl', 
                           );
    print "'$nav'\n";

=cut

sub html_table_navigation {
    my ($self,%args) = @_;
    my $pager = $args{-pager};

    my $nav;
    if (defined $args{-navigation} &&
        defined $args{-page_url}
	) {

	if ( lc($args{-navigation}) eq 'block' ) {
  
	    if ( $pager->previous_page ) {
	        $nav .= CGI::a( {href => "$args{-page_url}?page=" . $pager->previous_page} , 'prev' );
	
	    }
	
            if ($pager->previous_page && $pager->next_page) {
		$nav .= ' | ';
	    }
		
	     if ($pager->next_page) {
		$nav .= CGI::a( {href => "$args{-page_url}?page=" . $pager->next_page} , 'next' );
	    }
	} else {
	    foreach my $num ($pager->first_page .. $pager->last_page) {
                if ($num == $pager->current_page) { 
		    $nav .= "[ $num ]";
		} else {
		    $nav .= '[ ';
                    $nav .= CGI::a( { href => "$args{-page_url}?page=$num" } , $num );
		    $nav .= ' ]';
		}
		$nav .= ' ';
            }
	}
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

sub fill_in_form {
   my ($self,%args) = @_;
   my $fif = new HTML::FillInForm;
   return $fif->fill(%args);

}

=head2 add_bottom_span

Places the content you pass in at the bottom of the HTML::Table
object passed in.  Used for adding "submit" buttons or navigation to
the bottom of a table.

=cut

sub add_bottom_span {
    my ($self,$table,$add) = @_;
    $table->addRow( );
    $table->setCellColSpan( $table->getTableRows, 1 , $table->getTableCols  );
    $table->setCell($table->getTableRows, 1 , $add);
}

=head1 BUGS

Unknown at this time.

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