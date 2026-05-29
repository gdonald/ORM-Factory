use lib 'lib';
use BDD::Behave;
use ORM::Factory;
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

describe 'ORM::Factory.lint', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'no-arg variant lints every factory', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };
        .factory: 'post', { .title: 'Hello'; .association: 'author', :factory<user> };
      };
    }

    it 'runs successfully when every factory is healthy', {
      expect({ ORM::Factory.lint }).not.to.raise-error;
    }
  }

  context 'broken factory', {
    before-each {
      define {
        .factory: 'bad', { .association: 'author', :factory<ghost> };
      };
    }

    it 'aggregates failures into a LintFailures exception', {
      expect({ ORM::Factory.lint }).to.raise-error(X::ORM::Factory::LintFailures);
    }

    it 'attaches the list of failed factories', {
      my $err;
      try { ORM::Factory.lint; CATCH { default { $err = $_ } } }
      expect($err.failures.elems).to.eq(1);
    }

    it 'records the factory name on the failure', {
      my $err;
      try { ORM::Factory.lint; CATCH { default { $err = $_ } } }
      expect($err.failures[0]<factory>).to.eq('bad');
    }
  }

  context 'lint with :strategy<build>', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };
      };
    }

    it 'runs build instead of create', {
      ORM::Factory.lint(:strategy<build>);
      expect(ORM::Factory.factory-by-name('user').name).to.eq('user');
    }
  }

  context 'lint with :variants', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin', { .fname: 'Admin' };
          .variant: 'guest', { .fname: 'Guest' };
        };
      };
    }

    it 'passes when every variant is healthy', {
      expect({ ORM::Factory.lint(:variants) }).not.to.raise-error;
    }

    it 'detects a broken variant', {
      ORM::Factory.modify: {
        .factory: 'user', {
          .variant: 'broken', { .association: 'author', :factory<ghost> };
        };
      };
      my $err;
      try { ORM::Factory.lint(:variants); CATCH { default { $err = $_ } } }
      expect($err).to.be-a(X::ORM::Factory::LintFailures);
    }
  }

  context 'lint with a specific factory list', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };
        .factory: 'bad',  { .association: 'author', :factory<ghost> };
      };
    }

    it 'lints only the named factories', {
      expect({ ORM::Factory.lint('user') }).not.to.raise-error;
    }

    it 'still fails when a broken factory is named', {
      expect({ ORM::Factory.lint('bad') }).to.raise-error(X::ORM::Factory::LintFailures);
    }
  }

  context 'invalid record causes a LintFailures', {
    before-each {
      my class FailingPersistence does ORM::Factory::Persistence {
        method instantiate(Mu $class, %attrs) { $class.new(|%attrs) }
        method persist(Mu $instance) { $instance }
        method is-valid(Mu $instance --> Bool) { False }
        method errors(Mu $instance) { ('boom',) }
        method primary-key(Mu $class --> Str) { 'id' }
        method stub(Mu $instance) { $instance }
      }

      ORM::Factory.set-persistence(FailingPersistence.new);

      define {
        .factory: 'user', { .fname: 'Greg' };
      };
    }

    it 'raises a LintFailures wrapping InvalidRecord', {
      expect({ ORM::Factory.lint }).to.raise-error(X::ORM::Factory::LintFailures);
    }
  }
}

describe 'ORM::Factory introspection', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    define {
      .factory: 'user', :aliases<author>, {
        .fname: 'Greg';
        .variant: 'admin', { .fname: 'Admin' };
      };

      .factory: 'post', {
        .title: 'Hello';
        .association: 'author', :factory<user>;
      };

      .sequence: 'counter', -> $n { $n };
    };
  }

  context 'factory-names', {
    it 'returns every defined factory name', {
      expect(ORM::Factory.factory-names.List).to.eq(('post', 'user'));
    }
  }

  context 'sequence-names', {
    it 'returns every defined sequence name', {
      expect(ORM::Factory.sequence-names.List).to.eq(('counter',));
    }
  }

  context 'variant-names-for', {
    it 'returns variant names of the named factory', {
      expect(ORM::Factory.variant-names-for('user').List).to.eq(('admin',));
    }
  }

  context 'dump-attributes', {
    it 'lists every effective attribute', {
      expect(ORM::Factory.dump-attributes('user')<fname><has-value>).to.be-truthy;
    }

    it 'marks associations', {
      expect(ORM::Factory.dump-attributes('post')<author><association>).to.be-truthy;
    }

    it 'reflects override values', {
      expect(ORM::Factory.dump-attributes('user', :fname<Pat>)<fname>:exists).to.be-truthy;
    }
  }

  context 'describe-factory', {
    it 'returns a name', {
      expect(ORM::Factory.describe-factory('user')<name>).to.eq('user');
    }

    it 'returns aliases', {
      expect(ORM::Factory.describe-factory('user')<aliases>.List).to.eq(('author',));
    }

    it 'returns variant names', {
      expect(ORM::Factory.describe-factory('user')<variants>.List).to.eq(('admin',));
    }
  }
}

describe 'X::ORM::Factory error taxonomy', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  it 'X::ORM::Factory::UnknownFactory carries a message', {
    expect({ ORM::Factory.factory-by-name('ghost') }).to.raise-error(X::ORM::Factory::UnknownFactory);
  }

  it 'X::ORM::Factory::CyclicAssociation has a message', {
    define {
      .factory: 'user', :aliases<author>, {
        .fname: 'Greg';
        .association: 'best-post', :factory<post>;
      };

      .factory: 'post', { .title: 'Hi'; .author };
    };
    my $err;
    try { ORM::Factory.build('post'); CATCH { default { $err = $_ } } }
    expect($err.message.contains('cyclic')).to.be-truthy;
  }

  it 'X::ORM::Factory::InvalidRecord carries record and errors', {
    my $e = X::ORM::Factory::InvalidRecord.new(
      :message<boom>,
      :record(42),
      :factory-name<user>,
      :errors(<one two>),
    );
    expect($e.errors.List).to.eq(('one', 'two'));
  }
}
