use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use lib 'specs/lib';
use Factory::Test::Models;




our class Bag {
  has $.cargo is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

BEGIN GLOBAL::<User>    := User;
BEGIN GLOBAL::<Post>    := Post;
BEGIN GLOBAL::<Comment> := Comment;
BEGIN GLOBAL::<Bag>     := Bag;

publish-globals;

describe 'factory associations', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'implicit association (attribute name matches a factory alias)', {
    before-each {
      define {
        .factory: 'user', :aliases<author>, {
          .fname: 'Greg';
        };

        .factory: 'post', {
          .title:  'Hello';
          .author;
        };
      };
    }

    it 'resolves the bare-name attribute to a built association', {
      expect(ORM::Factory.build('post').author).to.be-a(User);
    }

    it 'populates the association with the target factory values', {
      expect(ORM::Factory.build('post').author.fname).to.eq('Greg');
    }

    it 'excludes implicit associations from attributes-for output', {
      expect(ORM::Factory.attributes-for('post').keys.sort.List).to.eq(('title',));
    }
  }

  context 'explicit association by attribute name', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
        };

        .factory: 'post', {
          .title: 'Hello';
          .association: 'author', :factory<user>;
        };
      };
    }

    it 'builds the association via the named target factory', {
      expect(ORM::Factory.build('post').author).to.be-a(User);
    }

    it 'records the association attribute on the factory definition', {
      my @assoc-names = ORM::Factory.factory-by-name('post').attributes.grep(*.association).map(*.name).list;
      expect(@assoc-names).to.eq(['author']);
    }

    it 'attributes-for omits explicit associations', {
      expect(ORM::Factory.attributes-for('post').keys.sort.List).to.eq(('title',));
    }
  }

  context 'association passing attribute overrides', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .role:  'member';
        };

        .factory: 'post', {
          .title: 'Hello';
          .association: 'author', :factory<user>, :role<owner>;
        };
      };
    }

    it 'forwards override keys to the association factory', {
      expect(ORM::Factory.build('post').author.role).to.eq('owner');
    }

    it 'leaves other association attributes untouched', {
      expect(ORM::Factory.build('post').author.fname).to.eq('Greg');
    }
  }

  context 'association applying variants', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .variant: 'admin', { .role: 'admin' };
        };

        .factory: 'post', {
          .association: 'author', 'admin', :factory<user>;
        };
      };
    }

    it 'applies the variant to the association', {
      expect(ORM::Factory.build('post').author.role).to.eq('admin');
    }
  }

  context 'association strategy override', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };

        .factory: 'post', {
          .title: 'Hello';
          .association: 'author', :factory<user>, :strategy<build>;
        };
      };
    }

    it 'uses the per-association strategy when explicitly set to build', {
      expect(ORM::Factory.create('post').author.saved).to.be-falsy;
    }

    it 'still persists the parent record', {
      expect(ORM::Factory.create('post').saved).to.be-truthy;
    }
  }

  context 'use-parent-strategy default behaviour', {
    before-each {
      define {
        .factory: 'user', :aliases<author>, { .fname: 'Greg' };

        .factory: 'post', {
          .title: 'Hello';
          .author;
        };
      };
    }

    it 'build cascades to a built association (unsaved)', {
      expect(ORM::Factory.build('post').author.saved).to.be-falsy;
    }

    it 'create cascades to a created association (saved)', {
      expect(ORM::Factory.create('post').author.saved).to.be-truthy;
    }

    it 'build-stubbed cascades to a stubbed association', {
      expect(ORM::Factory.build-stubbed('post').author).to.be-a(User);
    }
  }

  context 'inline association block referencing a transient', {
    before-each {
      define {
        .factory: 'user', { .fname: 'Greg' };

        .factory: 'post', {
          .transient: {
            .author-name: 'Inline';
          };
          .author: { ORM::Factory.build('user', :fname(.author-name)) };
        };
      };
    }

    it 'uses the transient value to build the association', {
      expect(ORM::Factory.build('post').author.fname).to.eq('Inline');
    }

    it 'override of the transient flows into the association', {
      expect(ORM::Factory.build('post', :author-name<Override>).author.fname).to.eq('Override');
    }
  }

  context 'polymorphic-style association via :factory', {
    before-each {
      define {
        .factory: 'post', {
          .title: 'Hello';
        };

        .factory: 'comment', {
          .body: 'Nice';
          .association: 'commentable', :factory<post>;
        };
      };
    }

    it 'targets the named factory for the polymorphic slot', {
      expect(ORM::Factory.build('comment').commentable).to.be-a(Post);
    }
  }

  context 'missing-association error', {
    before-each {
      define {
        .factory: 'post', {
          .association: 'author', :factory<ghost>;
        };
      };
    }

    it 'raises MissingAssociation when target factory is unknown', {
      expect({ ORM::Factory.build('post') }).to.raise-error(X::ORM::Factory::MissingAssociation);
    }
  }

  context 'cycle detection', {
    before-each {
      define {
        .factory: 'user', :aliases<author>, {
          .fname: 'Greg';
          .association: 'best-post', :factory<post>;
        };

        .factory: 'post', {
          .title: 'Hello';
          .author;
        };
      };
    }

    it 'detects a self-referential association loop', {
      expect({ ORM::Factory.build('post') }).to.raise-error(X::ORM::Factory::CyclicAssociation);
    }
  }
}
