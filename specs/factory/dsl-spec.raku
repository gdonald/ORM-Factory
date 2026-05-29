use lib 'lib';
use BDD::Behave;
use ORM::Factory;

describe 'define', {
  before-each {
    ORM::Factory.reload;
  }

  context 'factory registration', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
        };
      };
    }

    it 'registers the named factory', {
      expect(ORM::Factory.factories<user>.defined).to.be-truthy;
    }

    it 'exposes the factory by name', {
      expect(ORM::Factory.factory-by-name('user').name).to.eq('user');
    }

    it 'raises on unknown factory lookup', {
      expect({ ORM::Factory.factory-by-name('ghost') }).to.raise-error;
    }

    it 'raises on duplicate factory registration', {
      expect({
        define {
          .factory: 'user', { ; };
        };
      }).to.raise-error;
    }
  }

  context 'static attribute capture', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .lname: 'Donald';
        };
      };
    }

    it 'records two attributes', {
      expect(ORM::Factory.factory-by-name('user').attributes.elems).to.be(2);
    }

    it 'preserves declaration order', {
      my @names = ORM::Factory.factory-by-name('user').attributes.map(*.name).list;
      expect(@names).to.eq(['fname', 'lname']);
    }

    it 'marks static attributes as non-dynamic', {
      my @attrs = ORM::Factory.factory-by-name('user').attributes;
      expect(@attrs.map(*.dynamic).grep(?*).elems).to.be(0);
    }

    it 'stores the literal static value', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.value).to.eq('Greg');
    }
  }

  context 'dynamic block attribute', {
    before-each {
      define {
        .factory: 'user', {
          .email: { 'literal@example.com' };
        };
      };
    }

    it 'marks block attributes as dynamic', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.dynamic).to.be-truthy;
    }

    it 'captures the block', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.block).to.be-a(Callable);
    }

    it 'block evaluates to its body', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.block.()).to.eq('literal@example.com');
    }
  }

  context 'variant definition and application', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin', {
            .role: 'admin';
          };
          .admin;
        };
      };
    }

    it 'registers the variant', {
      expect(ORM::Factory.factory-by-name('user').variants<admin>.defined).to.be-truthy;
    }

    it 'records variant attributes', {
      my @attrs = ORM::Factory.factory-by-name('user').variants<admin>.attributes;
      expect(@attrs[0].name).to.eq('role');
    }

    it 'tracks the bare-name variant application', {
      my @applied = ORM::Factory.factory-by-name('user').applied-variants.list;
      expect(@applied).to.eq(['admin']);
    }

    it 'raises on duplicate variant in the same factory', {
      expect({
        ORM::Factory.reload;
        define {
          .factory: 'user', {
            .variant: 'admin', { ; };
            .variant: 'admin', { ; };
          };
        };
      }).to.raise-error;
    }
  }

  context 'add-attribute escape hatch', {
    before-each {
      define {
        .factory: 'user', {
          .add-attribute: 'factory', 'acme';
        };
      };
    }

    it 'records the colliding name as an attribute', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.name).to.eq('factory');
    }

    it 'stores its static value', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[0];
      expect($attr.value).to.eq('acme');
    }
  }

  context 'reload', {
    before-each {
      define {
        .factory: 'user', { ; };
      };
      ORM::Factory.reload;
    }

    it 'clears the registry', {
      expect(ORM::Factory.factories.elems).to.be(0);
    }

    it 'allows redefining a previously-registered factory', {
      define {
        .factory: 'user', { ; };
      };

      expect(ORM::Factory.factory-by-name('user').name).to.eq('user');
    }
  }
}
