use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;


our class Admin {
  has Str $.role;
}

# behave EVALs spec files; `our class Foo` declared during EVAL does not land
# in the runtime GLOBAL stash the way it does in a normal compunit. Bind the
# spec-local classes into GLOBAL so name-inference can find them. In a
# regular `t/*.rakutest` compunit (or production code), top-level `our class`
# declarations are in GLOBAL automatically.
BEGIN GLOBAL::<User>  := User;
BEGIN GLOBAL::<Admin> := Admin;

publish-globals;

describe 'class scope visibility (sanity)', {
  it 'GLOBAL contains the spec-file User class', {
    expect(GLOBAL::{'User'}:exists).to.be-truthy;
  }

  it 'GLOBAL::<User> is the User class', {
    expect(GLOBAL::{'User'}).to.be(User);
  }
}

describe 'factory class resolution', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(True);
  }

  after-each {
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'inference from factory name', {
    before-each {
      define {
        .factory: 'user', { ; };
      };
    }

    it 'derives the camelized class name', {
      expect(ORM::Factory.factory-by-name('user').class-name).to.eq('User');
    }

    it 'resolves a top-level class from GLOBAL', {
      expect(ORM::Factory.factory-by-name('user').class).to.be(User);
    }
  }

  context 'kebab and snake names camelize', {
    before-each {
      ORM::Factory.set-allow-class-lookup(False);
      define {
        .factory: 'super-admin',   { ; };
        .factory: 'team_lead',     { ; };
        .factory: 'top-level_mix', { ; };
      };
    }

    it 'kebab splits on hyphen', {
      expect(ORM::Factory.factory-by-name('super-admin').class-name).to.eq('SuperAdmin');
    }

    it 'snake splits on underscore', {
      expect(ORM::Factory.factory-by-name('team_lead').class-name).to.eq('TeamLead');
    }

    it 'mixed kebab + snake camelizes through both', {
      expect(ORM::Factory.factory-by-name('top-level_mix').class-name).to.eq('TopLevelMix');
    }
  }

  context 'explicit :class override', {
    before-each {
      define {
        .factory: 'super-admin', :class(Admin), { ; };
      };
    }

    it 'stores the explicit class', {
      expect(ORM::Factory.factory-by-name('super-admin').class).to.be(Admin);
    }

    it 'still computes the inferred class-name', {
      expect(ORM::Factory.factory-by-name('super-admin').class-name).to.eq('SuperAdmin');
    }
  }

  context 'allow-class-lookup toggle off', {
    before-each {
      ORM::Factory.set-allow-class-lookup(False);
      define {
        .factory: 'user', { ; };
      };
    }

    it 'leaves the class undefined', {
      expect(ORM::Factory.factory-by-name('user').class.defined).to.be-falsy;
    }
  }

  context 'unknown class', {
    before-each {
      define {
        .factory: 'phantom-thing', { ; };
      };
    }

    it 'class stays undefined when no GLOBAL class matches', {
      expect(ORM::Factory.factory-by-name('phantom-thing').class.defined).to.be-falsy;
    }

    it 'lookup-class raises X::ORM::Factory::UnknownClass', {
      expect({
        ORM::Factory.factory-by-name('phantom-thing').lookup-class;
      }).to.raise-error(X::ORM::Factory::UnknownClass);
    }
  }
}
