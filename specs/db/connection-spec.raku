use lib 'specs/lib';
use BDD::Behave;
use Factory::Test::Db;

describe 'configured database', {
  it 'answers a trivial query', {
    my $dbh = connect-database(%*ENV<DATABASE_URL>);
    LEAVE $dbh.dispose if $dbh;

    my $value = $dbh.execute('SELECT 1').row[0];

    expect($value.Int).to.be(1);
  }
}
