use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence;
use ORM::Factory::Persistence::Generic;

our class PUser {
  has Str  $.fname is rw;
  has Bool $.saved is rw = False;
  method save-or-die { $!saved = True; self }
}

BEGIN GLOBAL::<PUser> := PUser;

class CountingAdapter does ORM::Factory::Persistence {
  has Int $.instantiate-calls is rw = 0;
  has Int $.persist-calls     is rw = 0;
  has Int $.stub-calls        is rw = 0;

  method instantiate(Mu $class, %attrs) {
    $!instantiate-calls++;
    $class.new(|%attrs);
  }
  method persist(Mu $instance) {
    $!persist-calls++;
    $instance.save-or-die if $instance.^can('save-or-die');
    $instance;
  }
  method stub(Mu $instance) {
    $!stub-calls++;
    $instance;
  }
}

describe 'performance guards', {
  my $counting;

  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(False);
    $counting = CountingAdapter.new;
    ORM::Factory.set-persistence($counting);

    define {
      .factory: 'p-user', :class(PUser), {
        .fname: 'Greg';
      };
    };
  }

  after-each {
    ORM::Factory.reset-persistence;
  }

  context 'build-stubbed issues zero persist calls', {
    it 'never calls persist on the adapter', {
      ORM::Factory.build-stubbed('p-user');

      expect($counting.persist-calls).to.eq(0);
    }

    it 'calls instantiate once and stub once', {
      ORM::Factory.build-stubbed('p-user');

      expect($counting.instantiate-calls).to.eq(1);
      expect($counting.stub-calls).to.eq(1);
    }
  }

  context 'build issues zero persist calls', {
    it 'never calls persist on the adapter', {
      ORM::Factory.build('p-user');

      expect($counting.persist-calls).to.eq(0);
    }
  }

  context 'create issues exactly one persist call', {
    it 'calls persist once per record', {
      ORM::Factory.create('p-user');
      ORM::Factory.create('p-user');

      expect($counting.persist-calls).to.eq(2);
    }
  }

  context 'attributes-for issues zero adapter calls', {
    it 'never calls instantiate, persist, or stub', {
      ORM::Factory.attributes-for('p-user');

      expect($counting.instantiate-calls).to.eq(0);
      expect($counting.persist-calls).to.eq(0);
      expect($counting.stub-calls).to.eq(0);
    }
  }

  context 'evaluator memoisation', {
    it 'computes each attribute at most once per build', {
      my $hits = 0;

      ORM::Factory.reload;
      define {
        .factory: 'p-user', :class(PUser), {
          .fname: { $hits++; 'Greg' };
        };
      };

      my $u = ORM::Factory.build('p-user');

      $u.fname;
      $u.fname;
      $u.fname;

      expect($hits).to.eq(1);
    }
  }

}
