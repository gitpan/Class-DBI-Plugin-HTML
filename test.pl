package Foo;
use Test::More;
if (!require DBD::SQLite2) {
    plan skip_all => "Couldn't load DBD::SQLite2";
}
plan tests => 81;

package DBI::Test;
use base 'Class::DBI';

BEGIN { unlink 'test.db'; };
DBI::Test->set_db("Main", "dbi:SQLite2:dbname=test.db");
DBI::Test->db_Main->do("CREATE TABLE foo (
   id integer not null primary key,
   bar integer,
   baz varchar(255)
);");
DBI::Test->db_Main->do("CREATE TABLE bar (
   id integer not null primary key,
   test varchar(255)
);");
DBI::Test->table("test");
package Bar;
use base 'DBI::Test';
Bar->table("bar");
Bar->columns(All => qw/id test/);
Bar->columns(Stringify => qw/test/);
sub retrieve_all {
    bless { test => "Hi", id => 1}, shift;
}

package Foo;
use base 'DBI::Test';
use_ok("Class::DBI::Plugin::HTML");
use_ok("Class::DBI::AsForm");
use_ok("Class::DBI::AbstractSearch");
use_ok("Class::DBI::Pager");
use_ok("Class::DBI::Plugin::AbstractCount");
use_ok("Class::DBI::Plugin::RetrieveAll");
Foo->table("foo");

my $cdbi_html = Foo->html( -config_file => './examples/cdbi_config.ini' );

ok( $cdbi_html->isa( 'Foo' ) , "Proper Class" );

ok( $cdbi_html->config_file() eq './examples/cdbi_config.ini' , "config_file assignment: " . $cdbi_html->config_file() );
ok( -e $cdbi_html->config_file() , "config file exists" );
ok( $cdbi_html->display_columns( [ 'id', 'bar', 'baz' ] ) , "assign display columns" );
ok( $cdbi_html->display_columns->[0] eq 'id' , "column 0 equals id");

# simple method tests
foreach my $method ( @Class::DBI::Plugin::HTML::allowed_methods ) {
   
   #print "# set the method to 1 for testing\n";
   #print qq!
   ok( $cdbi_html->$method(1) , "attempt to set value for $method" );
   # print "# attempt to retrieve the 1 for testing\n";
   # print qq!
   ok( $cdbi_html->$method() , "attempt to return value for $method" );
}


