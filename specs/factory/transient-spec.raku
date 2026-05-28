use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class Greeting {
  has Str $.text is rw;
}

GLOBAL::<Greeting> := Greeting;

describe 'transient attributes', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    ORM::Factory.define: {
      .factory: 'greeting', {
        .transient: {
          .upcase: False;
          .who:    'World';
        };

        .text: { .upcase ?? "HELLO, {.who.uc}" !! "Hello, {.who}" };
      };
    };
  }

  context 'declaration', {
    it 'marks attributes inside .transient as transient', {
      my @attrs   = ORM::Factory.factory-by-name('greeting').attributes;
      my @t-names = @attrs.grep(*.transient).map(*.name).list;
      expect(@t-names).to.eq(['upcase', 'who']);
    }

    it 'leaves attributes outside .transient non-transient', {
      my @attrs    = ORM::Factory.factory-by-name('greeting').attributes;
      my @nt-names = @attrs.grep(!*.transient).map(*.name).list;
      expect(@nt-names).to.eq(['text']);
    }
  }

  context 'visibility', {
    it 'a dynamic attribute can read a transient value via the evaluator', {
      expect(ORM::Factory.build('greeting').text).to.eq('Hello, World');
    }

    it 'override of a transient value flows through to the dependent attribute', {
      expect(ORM::Factory.build('greeting', :who<Greg>).text).to.eq('Hello, Greg');
    }

    it 'override of a transient Bool flips a conditional branch', {
      expect(ORM::Factory.build('greeting', :upcase(True)).text).to.eq('HELLO, WORLD');
    }
  }

  context 'attributes-for excludes transient attributes', {
    it 'returns only the non-transient attributes', {
      expect(ORM::Factory.attributes-for('greeting').keys.sort.List).to.eq(('text',));
    }

    it 'still evaluates the dynamic non-transient attribute', {
      expect(ORM::Factory.attributes-for('greeting')<text>).to.eq('Hello, World');
    }
  }

  context 'transient values are not passed to the model constructor', {
    it 'build instantiates Greeting without `upcase` / `who` keys', {
      expect(ORM::Factory.build('greeting')).to.be-a(Greeting);
    }
  }
}
