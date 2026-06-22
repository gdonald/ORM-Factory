use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;



BEGIN GLOBAL::<User> := User;
BEGIN GLOBAL::<Post> := Post;

publish-globals;

describe 'factory variants', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'apply a variant at build time', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin', { .role: 'admin' };
        };
      };
    }

    it 'has no role without the variant', {
      expect(ORM::Factory.build('user').role).to.be(Str);
    }

    it 'applies the variant when named at build', {
      expect(ORM::Factory.build('user', 'admin').role).to.eq('admin');
    }

    it 'applies the variant via create', {
      expect(ORM::Factory.create('user', 'admin').role).to.eq('admin');
    }

    it 'applies the variant via build-stubbed', {
      expect(ORM::Factory.build-stubbed('user', 'admin').role).to.eq('admin');
    }

    it 'applies the variant via attributes-for', {
      expect(ORM::Factory.attributes-for('user', 'admin')<role>).to.eq('admin');
    }
  }

  context 'multiple runtime variants apply left-to-right', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin',  { .role: 'admin' };
          .variant: 'guest',  { .role: 'guest' };
          .variant: 'active', { .status: 'active' };
        };
      };
    }

    it 'later variant wins on overlapping attribute', {
      expect(ORM::Factory.build('user', 'admin', 'guest').role).to.eq('guest');
    }

    it 'non-overlapping attributes from earlier variant are preserved', {
      my $u = ORM::Factory.build('user', 'admin', 'active');
      expect($u.role).to.eq('admin');
    }

    it 'non-overlapping attributes from later variant are applied', {
      my $u = ORM::Factory.build('user', 'admin', 'active');
      expect($u.status).to.eq('active');
    }

    it 'reversed order flips precedence', {
      expect(ORM::Factory.build('user', 'guest', 'admin').role).to.eq('admin');
    }
  }

  context 'variant overrides an existing attribute', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
          .variant: 'admin', { .role: 'admin' };
        };
      };
    }

    it 'base attribute applies without the variant', {
      expect(ORM::Factory.build('user').role).to.eq('member');
    }

    it 'variant value overrides the base attribute', {
      expect(ORM::Factory.build('user', 'admin').role).to.eq('admin');
    }
  }

  context 'variant adds an association', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };

        .factory: 'post', {
          .title: 'Hello';
          .variant: 'authored', {
            .association: 'author', :factory<user>;
          };
        };
      };
    }

    it 'no association without the variant', {
      expect(ORM::Factory.build('post').author).to.be(User);
    }

    it 'variant attaches the association', {
      expect(ORM::Factory.build('post', 'authored').author).to.be-a(User);
    }
  }

  context 'variant adds a transient attribute', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .greeting: { "Hello, {.salute}" };
          .variant: 'shouty', {
            .transient: { .salute: 'WORLD' };
          };
        };
      };
    }

    it 'override of variant transient flows into dynamic attribute', {
      expect(ORM::Factory.build('user', 'shouty').greeting).to.eq('Hello, WORLD');
    }

    it 'attributes-for excludes the variant-added transient', {
      expect(ORM::Factory.attributes-for('user', 'shouty').keys.sort.List)
        .to.eq(('fname', 'greeting'));
    }
  }

  context 'variant references another variant', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'active', { .status: 'active' };
          .variant: 'admin',  { .active; .role: 'admin' };
        };
      };
    }

    it 'applying outer variant also applies the inner variant', {
      expect(ORM::Factory.build('user', 'admin').status).to.eq('active');
    }

    it 'outer variant attributes still apply', {
      expect(ORM::Factory.build('user', 'admin').role).to.eq('admin');
    }
  }

  context 'cyclic variant references terminate cleanly', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'a', { .b; .role: 'a' };
          .variant: 'b', { .a; .status: 'b' };
        };
      };
    }

    it 'applying one cycle endpoint still sets its attribute', {
      expect(ORM::Factory.build('user', 'a').role).to.eq('a');
    }

    it 'applying one cycle endpoint also runs the other side once', {
      expect(ORM::Factory.build('user', 'a').status).to.eq('b');
    }
  }

  context 'factory composed of variant references', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin',  { .role: 'admin' };
          .variant: 'active', { .status: 'active' };

          .factory: 'admin-active-user', {
            .admin;
            .active;
          };
        };
      };
    }

    it 'inherits parent attributes', {
      expect(ORM::Factory.build('admin-active-user').fname).to.eq('Greg');
    }

    it 'applies the first composed variant', {
      expect(ORM::Factory.build('admin-active-user').role).to.eq('admin');
    }

    it 'applies the second composed variant', {
      expect(ORM::Factory.build('admin-active-user').status).to.eq('active');
    }
  }

  context 'variant names usable as positional arguments in *-list', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin', { .role: 'admin' };
        };
      };
    }

    it 'build-list applies the variant to every element', {
      my @users = ORM::Factory.build-list('user', 3, 'admin');
      expect(@users.map(*.role).List).to.eq(('admin', 'admin', 'admin'));
    }

    it 'create-list applies the variant to every element', {
      my @users = ORM::Factory.create-list('user', 2, 'admin');
      expect(@users.map(*.role).List).to.eq(('admin', 'admin'));
    }

    it 'build-stubbed-list applies the variant to every element', {
      my @users = ORM::Factory.build-stubbed-list('user', 2, 'admin');
      expect(@users.map(*.role).List).to.eq(('admin', 'admin'));
    }

    it 'attributes-for-list applies the variant to every element', {
      my @hashes = ORM::Factory.attributes-for-list('user', 2, 'admin');
      expect(@hashes.map(*<role>).List).to.eq(('admin', 'admin'));
    }
  }

  context 'parameterised variant via a transient default + override', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'greeted', {
            .transient: { .salute: 'World' };
            .greeting:  { "Hello, {.salute}" };
          };
        };
      };
    }

    it 'uses the variant default for the transient', {
      expect(ORM::Factory.build('user', 'greeted').greeting).to.eq('Hello, World');
    }

    it 'caller override of the transient flows into the dynamic attribute', {
      expect(ORM::Factory.build('user', 'greeted', :salute<Greg>).greeting)
        .to.eq('Hello, Greg');
    }
  }

  context 'global variant defined at the top level', {
    before-each {
      define {
        .variant: 'flagged', { .flag: True };

        .factory: 'user', {
          .fname: 'Greg';
        };
      };
    }

    it 'registers the global variant', {
      expect(ORM::Factory.variants<flagged>.defined).to.be-truthy;
    }

    it 'applies the global variant at build time', {
      expect(ORM::Factory.build('user', 'flagged').flag).to.be-truthy;
    }

    it 'reload clears global variants', {
      ORM::Factory.reload;
      expect(ORM::Factory.variants.elems).to.be(0);
    }

    it 'raises on duplicate global variant', {
      expect({
        define {
          .variant: 'flagged', { .flag: False };
        };
      }).to.raise-error(X::ORM::Factory::DuplicateVariant);
    }
  }

  context 'global variant composed into a factory body', {
    before-each {
      define {
        .variant: 'flagged', { .flag: True };

        .factory: 'flagged-user', :class(User), {
          .fname: 'Greg';
          .flagged;
        };
      };
    }

    it 'applies the global variant when the factory is built', {
      expect(ORM::Factory.build('flagged-user').flag).to.be-truthy;
    }

    it 'leaves untouched attributes alone', {
      expect(ORM::Factory.build('flagged-user').fname).to.eq('Greg');
    }
  }

  context 'unknown variant at build time', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };
      };
    }

    it 'raises UnknownVariant for an undefined name', {
      expect({ ORM::Factory.build('user', 'ghost') })
        .to.raise-error(X::ORM::Factory::UnknownVariant);
    }
  }

  context 'variants-for-enum generates one variant per value', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variants-for-enum: 'role', <admin guest member>;
        };
      };
    }

    it 'registers a variant for each value', {
      my @names = ORM::Factory.factory-by-name('user').variants.keys.sort.List;
      expect(@names.List).to.eq(('admin', 'guest', 'member'));
    }

    it 'admin variant sets role to admin', {
      expect(ORM::Factory.build('user', 'admin').role).to.eq('admin');
    }

    it 'guest variant sets role to guest', {
      expect(ORM::Factory.build('user', 'guest').role).to.eq('guest');
    }

    it 'member variant sets role to member', {
      expect(ORM::Factory.build('user', 'member').role).to.eq('member');
    }
  }
}
