use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence;
use ORM::Factory::Persistence::Generic;

our class User {
  has Str  $.fname is rw;
  has Bool $.saved is rw = False;
  method save-or-die { $!saved = True; self }
}

our class Post {
  has Str  $.title  is rw;
  has User $.author is rw;
  has Bool $.saved  is rw = False;
  method save-or-die { $!saved = True; self }
}

BEGIN GLOBAL::<User> := User;
BEGIN GLOBAL::<Post> := Post;

describe 'ORM::Factory.configure', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
    ORM::Factory.set-use-parent-strategy(True);
  }

  after-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
    ORM::Factory.set-use-parent-strategy(True);
  }

  context 'entry point', {
    it 'accepts a builder block', {
      my Bool $ran;
      ORM::Factory.configure: { $ran = True };
      expect($ran).to.be-truthy;
    }
  }

  context 'allow-class-lookup', {
    it 'toggles the flag off', {
      ORM::Factory.configure: { .allow-class-lookup(False) };
      expect(ORM::Factory.allow-class-lookup).to.be-falsy;
    }

    it 'toggles the flag on', {
      ORM::Factory.set-allow-class-lookup(False);
      ORM::Factory.configure: { .allow-class-lookup(True) };
      expect(ORM::Factory.allow-class-lookup).to.be-truthy;
    }
  }

  context 'use-parent-strategy', {
    it 'defaults to True', {
      expect(ORM::Factory.use-parent-strategy).to.be-truthy;
    }

    it 'configure toggles the flag', {
      ORM::Factory.configure: { .use-parent-strategy(False) };
      expect(ORM::Factory.use-parent-strategy).to.be-falsy;
    }

    it 'reload resets it to True', {
      ORM::Factory.set-use-parent-strategy(False);
      ORM::Factory.reload;
      expect(ORM::Factory.use-parent-strategy).to.be-truthy;
    }

    context 'effect on associations during create', {
      before-each {
        define {
          .factory: 'user', :aliases<author>, { .fname: 'Greg' };
          .factory: 'post', { .title: 'Hi'; .author };
        };
      }

      it 'create persists the parent and the cascaded author when default', {
        my $p = ORM::Factory.create('post');
        expect($p.author.saved).to.be-truthy;
      }

      it 'build does not persist the cascaded author when default', {
        my $p = ORM::Factory.build('post');
        expect($p.author.saved).to.be-falsy;
      }

      it 'use-parent-strategy=False forces create-strategy on build', {
        ORM::Factory.set-use-parent-strategy(False);
        my $p = ORM::Factory.build('post');
        expect($p.author.saved).to.be-truthy;
      }
    }
  }

  context 'persistence selection', {
    it 'configure can install a custom persistence', {
      my $custom = ORM::Factory::Persistence::Generic.new;
      ORM::Factory.configure: { .persistence($custom) };
      expect(ORM::Factory.persistence).to.be($custom);
    }
  }

  context 'global hooks via configure', {
    it 'sets the global to-create', {
      my @captured;
      ORM::Factory.configure: { .to-create: -> $i, $e { @captured.push: $i } };
      define {
        .factory: 'user', { .fname: 'Greg' };
      };
      my $u = ORM::Factory.create('user');
      expect(@captured.elems).to.eq(1);
    }

    it 'sets the global initialize-with', {
      ORM::Factory.configure: { .initialize-with: -> $e { User.new(:fname<via-config>) } };
      define {
        .factory: 'user', { .fname: 'ignored' };
      };
      expect(ORM::Factory.build('user').fname).to.eq('via-config');
    }

    it 'sets global skip-create', {
      ORM::Factory.configure: { .skip-create(True) };
      define {
        .factory: 'user', { .fname: 'Greg' };
      };
      expect(ORM::Factory.create('user').saved).to.be-falsy;
    }
  }

  context 'definition-file-paths', {
    it 'returns the default search paths', {
      expect(ORM::Factory.definition-file-paths.first(* eq 'factories.raku').defined).to.be-truthy;
    }

    it 'configure can replace the search paths', {
      ORM::Factory.configure: { .definition-file-paths('custom-factories.raku') };
      expect(ORM::Factory.definition-file-paths.List).to.eq(('custom-factories.raku',));
    }
  }
}

describe 'ORM::Factory.find-definitions', {
  my $tmpdir;

  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    $tmpdir = ('specs/.tmp-defs-' ~ (^1000000).pick).IO;
    $tmpdir.mkdir;
  }

  after-each {
    ORM::Factory.reload;
    if $tmpdir.d {
      for $tmpdir.dir -> $f { $f.unlink if $f.f }
      $tmpdir.rmdir;
    }
    ORM::Factory.set-definition-file-paths(
      'factories.raku', 'spec/factories', 'specs/factories', 'test/factories', 't/factories'
    );
  }

  context 'a single .raku file', {
    before-each {
      my $f = $tmpdir.add('factories.raku');
      $f.spurt: q:to/END/;
      use ORM::Factory;
      define {
        .factory: 'user', :class(User), { .fname: 'Greg' };
      };
      END
      ORM::Factory.set-definition-file-paths($f.absolute);
    }

    it 'loads the factory', {
      ORM::Factory.find-definitions;
      expect(ORM::Factory.factory-exists('user')).to.be-truthy;
    }
  }

  context 'a directory of .raku files', {
    before-each {
      $tmpdir.add('a.raku').spurt: q:to/END/;
      use ORM::Factory;
      define {
        .factory: 'user', :class(User), { .fname: 'Greg' };
      };
      END
      $tmpdir.add('b.raku').spurt: q:to/END/;
      use ORM::Factory;
      define {
        .factory: 'post', :class(Post), { .title: 'Hi' };
      };
      END
      ORM::Factory.set-definition-file-paths($tmpdir.absolute);
    }

    it 'loads every .raku file', {
      ORM::Factory.find-definitions;
      expect(ORM::Factory.factory-exists('user')).to.be-truthy;
    }

    it 'merges definitions into a single registry', {
      ORM::Factory.find-definitions;
      expect(ORM::Factory.factory-exists('post')).to.be-truthy;
    }
  }

  context 'missing paths are skipped silently', {
    before-each {
      ORM::Factory.set-definition-file-paths('does/not/exist.raku');
    }

    it 'no exception is raised', {
      expect({ ORM::Factory.find-definitions }).not.to.raise-error;
    }
  }
}
