use v6.d;

unit module ORM::Factory::Cleanup;

class X::ORM::Factory::Cleanup is Exception {
  has Str $.message;
}

sub require-ar-or-die(Str:D $what --> Nil) {
  my $loaded = try { require ::('ORM::ActiveRecord::DB'); True };
  die X::ORM::Factory::Cleanup.new(
    message => "$what requires ORM::ActiveRecord to be loaded"
  ) unless $loaded;
}

sub ar-db {
  require ::('ORM::ActiveRecord::DB') <DB>;
  ::('DB').shared;
}

sub with-transaction-rollback(&block) is export {
  require-ar-or-die('with-transaction-rollback');

  my $db = ar-db;
  $db.begin;
  {
    CATCH {
      default {
        $db.rollback;
        .rethrow;
      }
    }
    block();
  }
  $db.rollback;
}

sub truncate-tables(*@tables --> Nil) is export {
  require-ar-or-die('truncate-tables');

  my $db   = ar-db;
  my $kind = $db.adapter.^name;
  for @tables -> $t {
    given $kind {
      when /Sqlite/ {
        $db.exec("DELETE FROM $t");
      }
      when /MySql/ {
        $db.exec("SET FOREIGN_KEY_CHECKS = 0");
        $db.exec("TRUNCATE TABLE $t");
        $db.exec("SET FOREIGN_KEY_CHECKS = 1");
      }
      default {
        $db.exec("TRUNCATE TABLE $t RESTART IDENTITY CASCADE");
      }
    }
  }
}

sub truncate-all-tables(--> Nil) is export {
  require-ar-or-die('truncate-all-tables');

  my @tables = ar-db.get-table-names.grep(* ne 'migrations').list;
  truncate-tables(|@tables);
}
