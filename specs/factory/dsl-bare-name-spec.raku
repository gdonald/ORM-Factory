use lib 'lib';
use lib 'specs/lib';
use BDD::Behave;
use ORM::Factory::DSL;
use Factory::Test::Models;

publish-globals;

# The opt-in bare-name DSL (ORM::Factory::DSL): keyword form + colon-pair form,
# both plain Raku, dispatching to the same builders as the canonical dotted DSL.

describe 'ORM::Factory::DSL bare-name form', {
  before-each {
    reload;
  }

  context 'keyword form with explicit attr setters', {
    before-each {
      define {
        sequence 'email', -> $n { "user{$n}\@example.com" };

        factory 'user', {
          attr 'fname', 'Greg';
          attr 'lname', 'Donald';
          attr 'email', { generate('email') };

          variant 'admin', {
            attr 'role', 'admin';
          };
        };
      };
    }

    it 'sets a static attribute', {
      expect(build('user').fname).to.eq('Greg');
    }

    it 'evaluates a dynamic attribute closure', {
      expect(build('user').email).to.eq('user1@example.com');
    }

    it 'applies a variant named at build time', {
      expect(build('user', 'admin').role).to.eq('admin');
    }

    it 'leaves the variant attribute unset without the variant', {
      expect(build('user').role).to.be(Str);
    }
  }

  context 'colon-pair form', {
    before-each {
      define {
        factory 'user', {
          attrs(
            :fname<Greg>,
            :lname<Donald>,
            :email({ 'greg@example.com' }),
          );
        };
      };
    }

    it 'sets static attributes from the pair list', {
      expect(build('user').fname).to.eq('Greg');
    }

    it 'treats a Callable pair value as a dynamic attribute', {
      expect(build('user').email).to.eq('greg@example.com');
    }
  }

  context 'associations and build helpers', {
    before-each {
      define {
        factory 'user', {
          attr 'fname', 'Greg';
        };

        factory 'post', {
          attr 'title', 'Hello';
          association 'author', :factory<user>;
        };
      };
    }

    it 'builds an explicit association through the bare-name keyword', {
      expect(build('post').author.fname).to.eq('Greg');
    }

    it 're-exports the build helpers (attributes-for)', {
      expect(attributes-for('post')<title>).to.eq('Hello');
    }
  }
};
