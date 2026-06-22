use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;


our class Worker {
  has Str $.title is rw;
}

BEGIN GLOBAL::<Person> := Person;
BEGIN GLOBAL::<Worker> := Worker;

publish-globals;

describe 'factory inheritance', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'nested factory definition', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
          .email: 'greg@example.com';

          .factory: 'admin', {
            .role: 'admin';
          };
        };
      };
    }

    it 'registers the nested child factory', {
      expect(ORM::Factory.factories<admin>.defined).to.be-truthy;
    }

    it 'records the parent name on the child', {
      expect(ORM::Factory.factory-by-name('admin').parent-name).to.eq('person');
    }

    it 'child inherits the parent fname attribute', {
      expect(ORM::Factory.build('admin').fname).to.eq('Greg');
    }

    it 'child inherits the parent email attribute', {
      expect(ORM::Factory.build('admin').email).to.eq('greg@example.com');
    }

    it 'child adds its own role attribute', {
      expect(ORM::Factory.build('admin').role).to.eq('admin');
    }

    it 'child uses parent class by default', {
      expect(ORM::Factory.factory-by-name('admin').lookup-class).to.be(Person);
    }
  }

  context 'child overrides parent attribute', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
        };

        .factory: 'admin-person', :parent('person'), {
          .fname: 'Admin Greg';
        };
      };
    }

    it 'override wins over parent', {
      expect(ORM::Factory.build('admin-person').fname).to.eq('Admin Greg');
    }
  }

  context 'transient inheritance', {
    before-each {
      define {
        .factory: 'person', {
          .transient: {
            .upcase: False;
          };
          .fname: { .upcase ?? 'GREG' !! 'Greg' };
        };

        .factory: 'admin-person', :parent('person'), {
          ;
        };
      };
    }

    it 'child build picks up parent transient default', {
      expect(ORM::Factory.build('admin-person').fname).to.eq('Greg');
    }

    it 'override of inherited transient flows through', {
      expect(ORM::Factory.build('admin-person', :upcase(True)).fname).to.eq('GREG');
    }

    it 'attributes-for on child excludes inherited transients', {
      expect(ORM::Factory.attributes-for('admin-person').keys.sort.List).to.eq(('fname',));
    }
  }

  context 'explicit :parent option', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
        };

        .factory: 'manager', :parent('person'), {
          .role: 'manager';
        };
      };
    }

    it 'registers the manager', {
      expect(ORM::Factory.factory-by-name('manager').parent-name).to.eq('person');
    }

    it 'inherits parent attribute', {
      expect(ORM::Factory.build('manager').fname).to.eq('Greg');
    }

    it 'adds child attribute', {
      expect(ORM::Factory.build('manager').role).to.eq('manager');
    }

    it 'raises on unknown parent', {
      expect({
        ORM::Factory.reload;
        define {
          .factory: 'manager', :parent('ghost'), { ; };
        };
      }).to.raise-error(X::ORM::Factory::UnknownFactory);
    }
  }

  context 'multi-level inheritance', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
        };

        .factory: 'manager', :parent('person'), {
          .role: 'manager';
        };

        .factory: 'cto', :parent('manager'), {
          .flag: True;
        };
      };
    }

    it 'chains through grandparent fname', {
      expect(ORM::Factory.build('cto').fname).to.eq('Greg');
    }

    it 'chains through parent role', {
      expect(ORM::Factory.build('cto').role).to.eq('manager');
    }

    it 'includes own flag attribute', {
      expect(ORM::Factory.build('cto').flag).to.be-truthy;
    }
  }

  context 'class inheritance', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
        };

        .factory: 'admin-person', :parent('person'), {
          .role: 'admin';
        };

        .factory: 'worker-person', :parent('person'), :class(Worker), {
          .title: 'Engineer';
        };
      };
    }

    it 'child without :class uses parent class', {
      expect(ORM::Factory.factory-by-name('admin-person').lookup-class).to.be(Person);
    }

    it 'child with :class overrides parent class', {
      expect(ORM::Factory.factory-by-name('worker-person').lookup-class).to.be(Worker);
    }
  }

  context 'variant inheritance', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
          .variant: 'admin', {
            .role: 'admin';
          };
        };

        .factory: 'admin-person', :parent('person'), {
          .admin;
        };
      };
    }

    it 'child can apply parent-defined variant by bare name', {
      expect(ORM::Factory.build('admin-person').role).to.eq('admin');
    }

    it 'parent attribute still flows through', {
      expect(ORM::Factory.build('admin-person').fname).to.eq('Greg');
    }
  }

  context 'modify updates an existing factory', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
          .email: 'greg@example.com';
        };
      };

      ORM::Factory.modify: {
        .factory: 'person', {
          .fname: 'Modified';
        };
      };
    }

    it 'overrides the matched attribute', {
      expect(ORM::Factory.build('person').fname).to.eq('Modified');
    }

    it 'leaves untouched attributes alone', {
      expect(ORM::Factory.build('person').email).to.eq('greg@example.com');
    }

    it 'raises on modifying an unknown factory', {
      expect({
        ORM::Factory.modify: {
          .factory: 'ghost', { ; };
        };
      }).to.raise-error(X::ORM::Factory::UnknownFactory);
    }
  }

  context 'modify propagates through inheritance', {
    before-each {
      define {
        .factory: 'person', {
          .fname: 'Greg';
        };

        .factory: 'admin-person', :parent('person'), {
          .role: 'admin';
        };
      };

      ORM::Factory.modify: {
        .factory: 'person', {
          .fname: 'Patched';
        };
      };
    }

    it 'child sees the modified parent attribute', {
      expect(ORM::Factory.build('admin-person').fname).to.eq('Patched');
    }

    it 'parent build also reflects the modification', {
      expect(ORM::Factory.build('person').fname).to.eq('Patched');
    }

    it 'child-defined attribute is preserved', {
      expect(ORM::Factory.build('admin-person').role).to.eq('admin');
    }
  }
}
