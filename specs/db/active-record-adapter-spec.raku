use lib 'lib';
use lib 'specs/lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence;
use ORM::Factory::Persistence::ActiveRecord;
use Factory::Test::AR;

publish-globals();

describe 'ORM::Factory::Persistence::ActiveRecord', {
  my $adapter;

  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    $adapter = ORM::Factory::Persistence::ActiveRecord.new;
    FactoryPost.destroy-all;
    FactoryUser.destroy-all;
  }

  context 'role conformance', {
    it 'does the Persistence role', {
      expect($adapter ~~ ORM::Factory::Persistence).to.be-truthy;
    }
  }

  context 'instantiate', {
    it 'uses the model build method when present', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg>, :lname<Donald> });

      expect($u).to.be-a(FactoryUser);
      expect($u.attrs<fname>).to.eq('Greg');
      expect($u.attrs<lname>).to.eq('Donald');
      expect($u.is-new-record).to.be-truthy;
    }

    it 'instantiates with no attributes', {
      my $u = $adapter.instantiate(FactoryUser, %());

      expect($u).to.be-a(FactoryUser);
      expect($u.is-new-record).to.be-truthy;
    }
  }

  context 'persist', {
    it 'persists a valid record via save-or-die', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg>, :lname<Donald> });
      $adapter.persist($u);
      expect($u.is-persisted).to.be-truthy;
      expect($u.id).to.be-greater-than(0);
    }

    it 'raises X::RecordInvalid on validation failure', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg> });
      expect({ $adapter.persist($u) }).to.raise-error;
    }
  }

  context 'is-valid + errors', {
    it 'is-valid returns True for a valid instance', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg>, :lname<Donald> });
      expect($adapter.is-valid($u)).to.be-truthy;
    }

    it 'is-valid returns False when validation fails', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg> });
      expect($adapter.is-valid($u)).to.be-falsy;
    }

    it 'errors returns the validation messages', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg> });
      $adapter.is-valid($u);
      my @errors = $adapter.errors($u).list;
      expect(@errors.elems).to.be-greater-than(0);
    }
  }

  context 'primary-key', {
    it 'returns id by default', {
      expect($adapter.primary-key(FactoryUser)).to.eq('id');
    }
  }

  context 'stub', {
    before-each {
      $adapter.reset-stub-counter;
    }

    it 'fakes a positive id without touching the database', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg>, :lname<Donald> });
      my $s = $adapter.stub($u);

      expect($s.id).to.be-greater-than(0);
      expect($s.is-persisted).to.be-truthy;
      expect($s.is-new-record).to.be-falsy;
    }

    it 'populates created_at and updated_at without touching the database', {
      my $u = $adapter.instantiate(FactoryUser, { :fname<Greg>, :lname<Donald> });
      my $s = $adapter.stub($u);

      expect($s.attrs<created_at>.defined).to.be-truthy;
      expect($s.attrs<updated_at>.defined).to.be-truthy;
    }

    it 'gives each stub a unique id', {
      my $a = $adapter.stub($adapter.instantiate(FactoryUser, { :fname<A>, :lname<A> }));
      my $b = $adapter.stub($adapter.instantiate(FactoryUser, { :fname<B>, :lname<B> }));

      expect($a.id).to.not.eq($b.id);
    }
  }

  context 'auto-detection by ORM::Factory', {
    it 'is selected by detect-persistence when AR is available', {
      ORM::Factory.reset-persistence;
      expect(ORM::Factory.persistence.^name).to.eq('ORM::Factory::Persistence::ActiveRecord');
    }
  }

  context 'integration through factory build/create/build-stubbed', {
    before-each {
      ORM::Factory.define: {
        .factory: 'factory-user', :class(FactoryUser), {
          .fname: 'Greg';
          .lname: 'Donald';
          .email: 'greg@example.com';
          .role:  'user';
        };
      };
    }

    it 'build returns an unsaved AR Model instance', {
      my $u = ORM::Factory.build('factory-user');
      expect($u).to.be-a(FactoryUser);
      expect($u.is-new-record).to.be-truthy;
    }

    it 'create persists via save-or-die', {
      my $u = ORM::Factory.create('factory-user');
      expect($u.is-persisted).to.be-truthy;
      expect($u.id).to.be-greater-than(0);
    }

    it 'build-stubbed returns a stubbed AR model', {
      my $u = ORM::Factory.build-stubbed('factory-user');
      expect($u.is-persisted).to.be-truthy;
      expect($u.attrs<created_at>.defined).to.be-truthy;
    }
  }
}
