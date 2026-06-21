use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class User {
  has Str  $.fname is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

BEGIN GLOBAL::<User> := User;

describe 'ORM::Factory bare-name helpers', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
    define {
      .factory: 'user', { .fname: 'Greg' };
      .sequence: 'counter', -> $n { $n };
    };
  }

  context 'definition entry point', {
    it 'define sub registers factories', {
      ORM::Factory.reload;
      define {
        .factory: 'user', { .fname: 'Greg' };
      };
      expect(ORM::Factory.factory-by-name('user').name).to.eq('user');
    }
  }

  context 'core build helpers', {
    it 'build sub delegates to ORM::Factory.build', {
      expect(build('user')).to.be-a(User);
    }

    it 'create sub delegates to ORM::Factory.create', {
      expect(create('user').saved).to.be-truthy;
    }

    it 'build-stubbed sub delegates to ORM::Factory.build-stubbed', {
      expect(build-stubbed('user')).to.be-a(User);
    }

    it 'attributes-for sub delegates to ORM::Factory.attributes-for', {
      expect(attributes-for('user')<fname>).to.eq('Greg');
    }
  }

  context 'collection helpers', {
    it 'build-list returns the requested count', {
      expect(build-list('user', 3).elems).to.eq(3);
    }

    it 'create-list returns the requested count', {
      expect(create-list('user', 2).map(*.saved).List).to.eq((True, True));
    }

    it 'build-stubbed-list returns the requested count', {
      expect(build-stubbed-list('user', 4).elems).to.eq(4);
    }

    it 'attributes-for-list returns the requested count', {
      expect(attributes-for-list('user', 2).elems).to.eq(2);
    }

    it 'build-pair returns two items', {
      expect(build-pair('user').elems).to.eq(2);
    }

    it 'create-pair returns two items', {
      expect(create-pair('user').elems).to.eq(2);
    }
  }

  context 'sequence helpers', {
    it 'generate delegates to ORM::Factory.generate', {
      expect(generate('counter')).to.eq(1);
    }

    it 'generate-list delegates to ORM::Factory.generate-list', {
      expect(generate-list('counter', 3).List).to.eq((1, 2, 3));
    }
  }

  context 'overrides flow through the helpers', {
    it 'forwards named overrides', {
      expect(build('user', :fname<Pat>).fname).to.eq('Pat');
    }
  }
}
