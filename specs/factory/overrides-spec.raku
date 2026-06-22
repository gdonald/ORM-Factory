use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;


GLOBAL::<Profile> := Profile;

publish-globals;

describe 'per-call attribute overrides', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    define {
      .factory: 'profile', {
        .fname: 'Greg';
        .email: { .fname.lc ~ '@example.com' };
        .nick:  'gd';
      };
    };
  }

  context 'static override of a static attribute', {
    it 'replaces the value', {
      expect(ORM::Factory.build('profile', :fname<Alice>).fname).to.eq('Alice');
    }

    it 'leaves other attributes unchanged', {
      expect(ORM::Factory.build('profile', :fname<Alice>).nick).to.eq('gd');
    }
  }

  context 'static override of a dynamic attribute', {
    it 'replaces the dynamic block with a static value', {
      expect(ORM::Factory.build('profile', :email<x@y.z>).email).to.eq('x@y.z');
    }
  }

  context 'block override of a static attribute', {
    it 'replaces the static with a dynamic block evaluated in the evaluator context', {
      my $obj = ORM::Factory.build('profile', :fname<Alice>, :nick({ .fname.uc }));
      expect($obj.nick).to.eq('ALICE');
    }
  }

  context 'block override of a dynamic attribute', {
    it 'replaces the original block with the override block', {
      my $obj = ORM::Factory.build('profile', :email({ 'literal@example.com' }));
      expect($obj.email).to.eq('literal@example.com');
    }
  }

  context 'override propagates through dependent attributes', {
    it 'a dependent attribute sees the overridden value', {
      expect(ORM::Factory.build('profile', :fname<Alice>).email).to.eq('alice@example.com');
    }
  }

  context 'overrides apply across all four build strategies', {
    it 'attributes-for sees the override', {
      expect(ORM::Factory.attributes-for('profile', :fname<Carol>)<fname>).to.eq('Carol');
    }

    it 'create sees the override', {
      expect(ORM::Factory.create('profile', :fname<Carol>).fname).to.eq('Carol');
    }

    it 'build-stubbed sees the override', {
      expect(ORM::Factory.build-stubbed('profile', :fname<Carol>).fname).to.eq('Carol');
    }
  }
}
