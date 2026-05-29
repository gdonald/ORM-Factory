use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class User {
  has Str  $.fname    is rw;
  has Str  $.role     is rw;
  has Str  $.status   is rw;
  has Str  $.greeting is rw;
  has Bool $.saved    is rw = False;
  has      @.events;
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

describe 'factory callbacks', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'after build', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .after: 'build', -> $u, $e { $u.fname = $u.fname.uc };
        };
      };
    }

    it 'fires the after-build callback on build', {
      expect(ORM::Factory.build('user').fname).to.eq('GREG');
    }

    it 'fires the after-build callback on create', {
      expect(ORM::Factory.create('user').fname).to.eq('GREG');
    }

    it 'does not fire after-build on build-stubbed', {
      expect(ORM::Factory.build-stubbed('user').fname).to.eq('Greg');
    }

    it 'does not fire after-build on attributes-for', {
      expect(ORM::Factory.attributes-for('user')<fname>).to.eq('Greg');
    }
  }

  context 'before create and after create', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .before: 'create', -> $u, $e { $u.events.push: 'before-create' };
          .after:  'create', -> $u, $e { $u.events.push: 'after-create'  };
        };
      };
    }

    it 'fires before-create before persistence on create', {
      my $u = ORM::Factory.create('user');
      expect($u.events.head).to.eq('before-create');
    }

    it 'fires after-create after persistence on create', {
      my $u = ORM::Factory.create('user');
      expect($u.events.tail).to.eq('after-create');
    }

    it 'does not fire create callbacks on build', {
      expect(ORM::Factory.build('user').events.elems).to.eq(0);
    }
  }

  context 'after stub', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .after: 'stub', -> $u, $e { $u.events.push: 'stubbed' };
        };
      };
    }

    it 'fires after-stub on build-stubbed', {
      expect(ORM::Factory.build-stubbed('user').events).to.eq(['stubbed']);
    }

    it 'does not fire after-stub on build', {
      expect(ORM::Factory.build('user').events.elems).to.eq(0);
    }

    it 'does not fire after-stub on create', {
      expect(ORM::Factory.create('user').events.elems).to.eq(0);
    }
  }

  context 'block receives the instance and the evaluator', {
    before-each {
      define {
        .factory: 'user', {
          .fname:   'Greg';
          .role:    'member';
          .after: 'build', -> $u, $e {
            $u.status = "{$e.fname}:{$e.role}";
          };
        };
      };
    }

    it 'passes the instance as the first argument', {
      expect(ORM::Factory.build('user').status).to.eq('Greg:member');
    }
  }

  context 'multiple callbacks for one event run in declaration order', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .after: 'build', -> $u, $e { $u.events.push: 'one' };
          .after: 'build', -> $u, $e { $u.events.push: 'two' };
          .after: 'build', -> $u, $e { $u.events.push: 'three' };
        };
      };
    }

    it 'fires the callbacks in declaration order', {
      expect(ORM::Factory.build('user').events).to.eq(['one', 'two', 'three']);
    }
  }

  context 'parent callbacks run before child callbacks', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .after: 'build', -> $u, $e { $u.events.push: 'parent' };

          .factory: 'admin', {
            .role: 'admin';
            .after: 'build', -> $u, $e { $u.events.push: 'child' };
          };
        };
      };
    }

    it 'parent callback fires first when child is built', {
      expect(ORM::Factory.build('admin').events).to.eq(['parent', 'child']);
    }

    it 'parent built on its own only fires the parent callback', {
      expect(ORM::Factory.build('user').events).to.eq(['parent']);
    }
  }

  context 'variant callbacks merge with factory callbacks', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .after: 'build', -> $u, $e { $u.events.push: 'base' };
          .variant: 'noisy', {
            .after: 'build', -> $u, $e { $u.events.push: 'noisy' };
          };
        };
      };
    }

    it 'only the factory callback fires without the variant', {
      expect(ORM::Factory.build('user').events).to.eq(['base']);
    }

    it 'factory callback fires before the variant callback when the variant is applied', {
      expect(ORM::Factory.build('user', 'noisy').events).to.eq(['base', 'noisy']);
    }
  }

  context 'global callbacks apply to every factory', {
    before-each {
      define {
        .after: 'build', -> $i, $e { $i.events.push: 'global' };

        .factory: 'user', {
          .fname: 'Greg';
          .after: 'build', -> $u, $e { $u.events.push: 'user' };
        };

        .factory: 'admin', :class(User), {
          .fname: 'Boss';
        };
      };
    }

    it 'global runs for the factory that has no own callbacks', {
      expect(ORM::Factory.build('admin').events).to.eq(['global']);
    }

    it 'global runs before the factory-defined callback', {
      expect(ORM::Factory.build('user').events).to.eq(['global', 'user']);
    }

    it 'reload clears global callbacks', {
      ORM::Factory.reload;
      expect(ORM::Factory.global-callbacks.elems).to.eq(0);
    }
  }

  context 'custom callbacks via callback and run-callbacks', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .callback: 'shouted', -> $u, $e { $u.fname = $u.fname.uc };
          .after: 'build', -> $u, $e { $e.run-callbacks('shouted') };
        };
      };
    }

    it 'registers the custom callback on the factory definition', {
      my @names = ORM::Factory.factory-by-name('user').callbacks.map(*.event).List;
      expect(@names).to.eq(['shouted', 'after-build']);
    }

    it 'evaluator.run-callbacks fires the custom callback', {
      expect(ORM::Factory.build('user').fname).to.eq('GREG');
    }

    it 'unknown custom callback is a no-op (run-callbacks finds nothing)', {
      my $u = ORM::Factory.build('user');
      expect($u.fname).to.eq('GREG');
    }
  }

  context 'callbacks see overrides and dependent attributes', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .greeting: { "hi, {.fname}" };
          .after: 'build', -> $u, $e { $u.greeting = $u.greeting.uc };
        };
      };
    }

    it 'callback can post-process a dynamic attribute', {
      expect(ORM::Factory.build('user').greeting).to.eq('HI, GREG');
    }

    it 'caller override flows through the dynamic attribute and into the callback', {
      expect(ORM::Factory.build('user', :fname<Pat>).greeting).to.eq('HI, PAT');
    }
  }

  context 'has_many-style collections via callback + transient count', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
        };

        .factory: 'post', {
          .title: 'Hello';

          .transient: {
            .comments-count: 0;
          };

          .after: 'build', -> $p, $e {
            for ^$e.comments-count -> $i {
              $p.author = ORM::Factory.build('user', :fname("commenter-$i"));
            }
          };
        };
      };
    }

    it 'transient count of 0 leaves the collection alone', {
      expect(ORM::Factory.build('post').author).to.be(User);
    }

    it 'transient count drives how many times the loop runs', {
      expect(ORM::Factory.build('post', :comments-count(3)).author.fname).to.eq('commenter-2');
    }

    it 'attributes-for excludes the transient count', {
      expect(ORM::Factory.attributes-for('post').keys.sort.List).to.eq(('title',));
    }
  }
}
