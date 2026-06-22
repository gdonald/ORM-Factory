use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;



BEGIN GLOBAL::<User> := User;
BEGIN GLOBAL::<Profile> := Profile;

publish-globals;

describe 'initialize-with', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'per-factory initialize-with', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .initialize-with: -> $e { User.new(|$e.attributes, :via('hook')) };
        };
      };
    }

    it 'replaces the default constructor', {
      expect(ORM::Factory.build('user').via).to.eq('hook');
    }

    it 'still passes the factory attributes through', {
      expect(ORM::Factory.build('user').fname).to.eq('Greg');
    }

    it 'fires after-build callbacks on the hook-built instance', {
      ORM::Factory.reload;
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .initialize-with: -> $e { User.new(|$e.attributes, :via('hook')) };
          .after: 'build', -> $u, $e { $u.events.push: 'after-build' };
        };
      };
      expect(ORM::Factory.build('user').events).to.eq(['after-build']);
    }

    it 'is also used by create', {
      expect(ORM::Factory.create('user').via).to.eq('hook');
    }

    it 'is also used by build-stubbed', {
      expect(ORM::Factory.build-stubbed('user').via).to.eq('hook');
    }

    it 'is bypassed by attributes-for', {
      expect(ORM::Factory.attributes-for('user')<fname>).to.eq('Greg');
    }
  }

  context 'attributes helper inside initialize-with', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .email: 'x@example.com';
          .initialize-with: -> $e {
            User.new(|$e.attributes);
          };
        };
      };
    }

    it 'returns the resolved persisted-attribute hash', {
      my %h = ORM::Factory.attributes-for('user');
      my $u = ORM::Factory.build('user');
      aggregate-failures 'identical view from attributes-for and attributes', {
        expect($u.fname).to.eq(%h<fname>);
        expect($u.role).to.eq(%h<role>);
        expect($u.email).to.eq(%h<email>);
      };
    }
  }

  context 'global initialize-with', {
    before-each {
      define {
        .initialize-with: -> $e { User.new(|$e.attributes, :via('global')) };

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
        };
      };
    }

    it 'applies to every factory with no per-factory hook', {
      expect(ORM::Factory.build('user').via).to.eq('global');
    }

    it 'is overridden by a per-factory initialize-with', {
      ORM::Factory.reload;
      define {
        .initialize-with: -> $e { User.new(|$e.attributes, :via('global')) };

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .initialize-with: -> $e { User.new(|$e.attributes, :via('factory')) };
        };
      };
      expect(ORM::Factory.build('user').via).to.eq('factory');
    }

    it 'reload clears the global initialize-with', {
      ORM::Factory.reload;
      expect(ORM::Factory.global-initialize-with.defined).to.be-falsy;
    }
  }

  context 'inheritance', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .initialize-with: -> $e { User.new(|$e.attributes, :via('parent')) };

          .factory: 'admin', {
            .role: 'admin';
          };

          .factory: 'shouty', {
            .role: 'shout';
            .initialize-with: -> $e { User.new(|$e.attributes, :via('child')) };
          };
        };
      };
    }

    it 'child inherits the parent initialize-with', {
      expect(ORM::Factory.build('admin').via).to.eq('parent');
    }

    it 'child can override the parent initialize-with', {
      expect(ORM::Factory.build('shouty').via).to.eq('child');
    }
  }
}

describe 'to-create', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'per-factory to-create', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .to-create: -> $u, $e { $u.via = 'custom'; $u.saved = True };
        };
      };
    }

    it 'replaces the default persistence call', {
      my $u = ORM::Factory.create('user');
      aggregate-failures 'custom persistence ran', {
        expect($u.via).to.eq('custom');
        expect($u.saved).to.be-truthy;
      };
    }

    it 'fires before-create / after-create around the custom persistence', {
      ORM::Factory.reload;
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .before: 'create', -> $u, $e { $u.events.push: 'before' };
          .to-create: -> $u, $e { $u.events.push: 'persist' };
          .after:  'create', -> $u, $e { $u.events.push: 'after' };
        };
      };
      expect(ORM::Factory.create('user').events).to.eq(['before', 'persist', 'after']);
    }

    it 'is not consulted by build', {
      my $u = ORM::Factory.build('user');
      expect($u.saved).to.be-falsy;
    }
  }

  context 'global to-create', {
    before-each {
      define {
        .to-create: -> $u, $e { $u.via = 'global'; $u.saved = True };

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
        };
      };
    }

    it 'applies to every factory with no per-factory hook', {
      expect(ORM::Factory.create('user').via).to.eq('global');
    }

    it 'is overridden by a per-factory to-create', {
      ORM::Factory.reload;
      define {
        .to-create: -> $u, $e { $u.via = 'global' };

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .to-create: -> $u, $e { $u.via = 'factory'; $u.saved = True };
        };
      };
      expect(ORM::Factory.create('user').via).to.eq('factory');
    }

    it 'reload clears the global to-create', {
      ORM::Factory.reload;
      expect(ORM::Factory.global-to-create.defined).to.be-falsy;
    }
  }

  context 'inheritance', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .to-create: -> $u, $e { $u.via = 'parent'; $u.saved = True };

          .factory: 'admin', {
            .role: 'admin';
          };

          .factory: 'mongo', {
            .role: 'mongo';
            .to-create: -> $u, $e { $u.via = 'child'; $u.saved = True };
          };
        };
      };
    }

    it 'child inherits the parent to-create', {
      expect(ORM::Factory.create('admin').via).to.eq('parent');
    }

    it 'child can override the parent to-create', {
      expect(ORM::Factory.create('mongo').via).to.eq('child');
    }
  }
}

describe 'skip-create', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'per-factory skip-create', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .skip-create;
        };
      };
    }

    it 'makes create behave like build (no save)', {
      expect(ORM::Factory.create('user').saved).to.be-falsy;
    }

    it 'still runs after-build / before-create / after-create callbacks', {
      ORM::Factory.reload;
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .skip-create;
          .after:  'build',  -> $u, $e { $u.events.push: 'after-build'   };
          .before: 'create', -> $u, $e { $u.events.push: 'before-create' };
          .after:  'create', -> $u, $e { $u.events.push: 'after-create'  };
        };
      };
      expect(ORM::Factory.create('user').events).to.eq(['after-build', 'before-create', 'after-create']);
    }
  }

  context 'global skip-create', {
    before-each {
      define {
        .skip-create;

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
        };
      };
    }

    it 'applies to every factory with no per-factory hook', {
      expect(ORM::Factory.create('user').saved).to.be-falsy;
    }

    it 'is overridden by a per-factory to-create', {
      ORM::Factory.reload;
      define {
        .skip-create;

        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .to-create: -> $u, $e { $u.saved = True };
        };
      };
      expect(ORM::Factory.create('user').saved).to.be-truthy;
    }

    it 'reload clears the global skip-create', {
      ORM::Factory.reload;
      expect(ORM::Factory.global-skip-create.defined).to.be-falsy;
    }
  }

  context 'inheritance', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .skip-create;

          .factory: 'admin', {
            .role: 'admin';
          };

          .factory: 'saver', {
            .role: 'saver';
            .to-create: -> $u, $e { $u.saved = True };
          };
        };
      };
    }

    it 'child inherits the parent skip-create', {
      expect(ORM::Factory.create('admin').saved).to.be-falsy;
    }

    it 'child to-create overrides the parent skip-create', {
      expect(ORM::Factory.create('saver').saved).to.be-truthy;
    }
  }
}
