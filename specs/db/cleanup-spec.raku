use lib 'lib';
use lib 'specs/lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Cleanup;
use Factory::Test::AR;

publish-globals();

describe 'ORM::Factory::Cleanup', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    Post.destroy-all;
    User.destroy-all;

    define {
      .factory: 'user', :class(User), {
        .fname: 'Greg';
        .lname: 'Donald';
        .email: 'greg@example.com';
        .role:  'user';
      };
    };
  }

  context 'with-transaction-rollback', {
    it 'creates inside the block but rolls back on exit', {
      with-transaction-rollback {
        ORM::Factory.create-list('user', 3);
      };

      expect(User.count).to.eq(0);
    }

    it 'rolls back even when an exception is raised', {
      try {
        with-transaction-rollback {
          ORM::Factory.create('user');
          die 'simulated test failure';
        };
      };

      expect(User.count).to.eq(0);
    }
  }

  context 'truncate-tables', {
    before-each {
      ORM::Factory.create-list('user', 2);
    }

    it 'removes all rows from the named table', {
      expect(User.count).to.eq(2);
      truncate-tables('users');
      expect(User.count).to.eq(0);
    }
  }

  context 'truncate-all-tables', {
    before-each {
      ORM::Factory.create-list('user', 2);
    }

    it 'removes all rows except migrations', {
      truncate-all-tables();
      expect(User.count).to.eq(0);
    }
  }
}
