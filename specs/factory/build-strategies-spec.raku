use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class Person {
  has Str  $.fname is rw;
  has Str  $.lname is rw;
  has Str  $.email is rw;
  has Str  $.role  is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

GLOBAL::<Person> := Person;

describe 'core build strategies', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    define {
      .factory: 'person', {
        .fname: 'Greg';
        .lname: 'Donald';
        .email: { .fname.lc ~ '@example.com' };

        .variant: 'admin', {
          .role: 'admin';
        };
      };
    };
  }

  after-each { ORM::Factory.reset-persistence; }

  context 'build', {
    it 'returns an instance of the factory class', {
      expect(ORM::Factory.build('person')).to.be-a(Person);
    }

    it 'populates static attributes', {
      expect(ORM::Factory.build('person').fname).to.eq('Greg');
    }

    it 'populates dynamic attributes using the evaluator', {
      expect(ORM::Factory.build('person').email).to.eq('greg@example.com');
    }

    it 'does not save the instance', {
      expect(ORM::Factory.build('person').saved).to.be-falsy;
    }
  }

  context 'create', {
    it 'returns an instance of the factory class', {
      expect(ORM::Factory.create('person')).to.be-a(Person);
    }

    it 'persists the instance via the adapter', {
      expect(ORM::Factory.create('person').saved).to.be-truthy;
    }
  }

  context 'attributes-for', {
    it 'returns a Hash', {
      expect(ORM::Factory.attributes-for('person')).to.be-a(Hash);
    }

    it 'includes static attributes', {
      expect(ORM::Factory.attributes-for('person')<fname>).to.eq('Greg');
    }

    it 'evaluates dynamic attributes', {
      expect(ORM::Factory.attributes-for('person')<email>).to.eq('greg@example.com');
    }

    it 'does not instantiate or persist', {
      ORM::Factory.attributes-for('person');
      expect(Person.new.saved).to.be-falsy;
    }
  }

  context 'build-stubbed', {
    it 'returns an instance of the factory class', {
      expect(ORM::Factory.build-stubbed('person')).to.be-a(Person);
    }

    it 'does not persist (Generic adapter)', {
      expect(ORM::Factory.build-stubbed('person').saved).to.be-falsy;
    }
  }

  context 'variant application at build time', {
    it 'applies a single positional variant', {
      expect(ORM::Factory.build('person', 'admin').role).to.eq('admin');
    }

    it 'unknown variant raises X::ORM::Factory::UnknownVariant', {
      expect({ ORM::Factory.build('person', 'ghost') }).to.raise-error(X::ORM::Factory::UnknownVariant);
    }
  }
}
