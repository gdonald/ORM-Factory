use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class CUser {
  has Str $.fname is rw;
  has Int $.counter is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

BEGIN GLOBAL::<CUser> := CUser;

describe 'concurrency', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(True);
    ORM::Factory.reset-persistence;
  }

  context 'sequence atomicity', {
    before-each {
      define {
        .sequence: 'serial';
      };
    }

    it 'produces a contiguous unique sequence under concurrent generate', {
      my @results = (^200).hyper(:degree(8), :batch(1)).map({
        ORM::Factory.generate('serial');
      }).list;

      expect(@results.unique.elems).to.eq(200);
      expect(@results.min).to.eq(1);
      expect(@results.max).to.eq(200);
    }
  }

  context 'concurrent builds', {
    before-each {
      define {
        .sequence: 'sn';
        .factory: 'c-user', :class(CUser), {
          .fname:  'C';
          .counter: { ORM::Factory.generate('sn') };
        };
      };
    }

    it 'produces unique serial numbers across threads', {
      my @users = (^100).hyper(:degree(8), :batch(1)).map({
        ORM::Factory.build('c-user');
      }).list;

      my @serials = @users.map(*.counter);
      expect(@serials.unique.elems).to.eq(100);
    }

    it 'isolates per-build evaluator state across threads', {
      my @users = (^50).hyper(:degree(4), :batch(1)).map({
        ORM::Factory.build('c-user', fname => "name-$_");
      }).list;

      my @names = @users.map(*.fname).sort;
      expect(@names.join(',')).to.eq((^50).map({ "name-$_" }).sort.join(','));
    }
  }

  context 'rewind-sequences is safe under concurrency', {
    before-each {
      define {
        .sequence: 'r';
      };
    }

    it 'completes without errors when rewound while running', {
      my $count = 50;
      my @values = (^$count).hyper(:degree(4), :batch(1)).map({
        ORM::Factory.rewind-sequences if $_ %% 10;
        ORM::Factory.generate('r');
      }).list;

      expect(@values.elems).to.eq($count);
    }
  }
}
