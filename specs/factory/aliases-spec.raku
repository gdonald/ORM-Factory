use lib 'lib';
use BDD::Behave;
use ORM::Factory;

describe 'factory aliases', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(False);
  }

  after-each {
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'a factory with aliases', {
    before-each {
      define {
        .factory: 'user', :aliases<author commenter>, {
          .fname: 'Greg';
        };
      };
    }

    it 'records the aliases on the definition', {
      my @aliases = ORM::Factory.factory-by-name('user').aliases.list;
      expect(@aliases).to.eq(['author', 'commenter']);
    }

    it 'registers each alias in the global alias map', {
      expect(ORM::Factory.aliases<author>).to.eq('user');
    }

    it 'looks up the factory by its alias', {
      expect(ORM::Factory.factory-by-name('author').name).to.eq('user');
    }

    it 'returns the same FactoryDefinition for alias and canonical name', {
      expect(ORM::Factory.factory-by-name('commenter')).to.be(ORM::Factory.factory-by-name('user'));
    }
  }

  context 'collision detection', {
    it 'rejects an alias that already names another factory', {
      expect({
        define {
          .factory: 'user',  { ; };
          .factory: 'other', :aliases<user>, { ; };
        };
      }).to.raise-error(X::ORM::Factory::DuplicateAlias);
    }

    it 'rejects two factories claiming the same alias', {
      expect({
        define {
          .factory: 'user',  :aliases<author>, { ; };
          .factory: 'other', :aliases<author>, { ; };
        };
      }).to.raise-error(X::ORM::Factory::DuplicateAlias);
    }

    it 'rejects a factory name that collides with an existing alias', {
      define {
        .factory: 'user', :aliases<author>, { ; };
      };
      expect({
        define {
          .factory: 'author', { ; };
        };
      }).to.raise-error(X::ORM::Factory::DuplicateAlias);
    }
  }

  context 'reload', {
    before-each {
      define {
        .factory: 'user', :aliases<author>, { ; };
      };
      ORM::Factory.reload;
    }

    it 'clears aliases', {
      expect(ORM::Factory.aliases.elems).to.be(0);
    }

    it 'lookup by old alias raises X::ORM::Factory::UnknownFactory', {
      expect({ ORM::Factory.factory-by-name('author') }).to.raise-error(X::ORM::Factory::UnknownFactory);
    }
  }
}
