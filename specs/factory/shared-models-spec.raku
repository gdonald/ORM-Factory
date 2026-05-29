use lib 'lib';
use lib 'specs/lib';
use BDD::Behave;
use ORM::Factory;
use Factory::Test::Models;

publish-globals();

describe 'shared test models from specs/lib', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    define {
      .factory: 'user', :aliases<author>, {
        .fname: 'Greg';
        .lname: 'Donald';
        .email: { .fname.lc ~ '@example.com' };
      };

      .factory: 'post', {
        .title: 'Hi';
        .body:  'world';
        .author;
      };
    };
  }

  it 'resolves the shared User class via GLOBAL', {
    expect(ORM::Factory.build('user')).to.be-a(User);
  }

  it 'resolves the shared Post class via GLOBAL', {
    expect(ORM::Factory.build('post')).to.be-a(Post);
  }

  it 'evaluates dynamic attributes against the shared model', {
    expect(ORM::Factory.build('user').email).to.eq('greg@example.com');
  }

  it 'cascades the implicit author association', {
    expect(ORM::Factory.build('post').author).to.be-a(User);
  }
}
