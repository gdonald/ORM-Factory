use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence::Generic;

our class Note {
  has Str  $.title is rw;
  has Str  $.body  is rw;
  has Bool $.saved is rw = False;
  method save-or-die { $!saved = True; self }
}

our class Article {
  has Str  $.title  is rw;
  has Note $.author is rw;
  has Bool $.saved  is rw = False;
  method save-or-die { $!saved = True; self }
}

BEGIN GLOBAL::<Note>    := Note;
BEGIN GLOBAL::<Article> := Article;

our class JsonStrategy does ORM::Factory::Strategy {
  method to-sym(--> Str) { 'json' }
  method result(ORM::Factory::Evaluator $eval) {
    my %h = $eval.attributes-hash(:skip-associations);
    'JSON:' ~ %h.kv.map(-> $k, $v { "$k=$v" }).sort.join(',');
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build($name, |@variants, |%overrides);
  }
}

our class ShoutBuildStrategy does ORM::Factory::Strategy {
  method to-sym(--> Str) { 'build' }
  method result(ORM::Factory::Evaluator $eval) {
    my $instance = $!persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
    $eval.instance = $instance;
    $instance.title = $instance.title.uc if $instance.^can('title');
    $instance;
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build($name, |@variants, |%overrides);
  }
}

our class StubAssocStrategy does ORM::Factory::Strategy {
  method to-sym(--> Str) { 'cascade-stub' }
  method result(ORM::Factory::Evaluator $eval) {
    $!persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build-stubbed($name, |@variants, |%overrides);
  }
}

BEGIN GLOBAL::<JsonStrategy>       := JsonStrategy;
BEGIN GLOBAL::<ShoutBuildStrategy> := ShoutBuildStrategy;
BEGIN GLOBAL::<StubAssocStrategy>  := StubAssocStrategy;

describe 'custom strategies', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
    ORM::Factory.unregister-strategy('json');
    ORM::Factory.unregister-strategy('cascade-stub');
    ORM::Factory.register-strategy('build', ORM::Factory::BuildStrategy);
    ORM::Factory.register-strategy('create', ORM::Factory::CreateStrategy);
    ORM::Factory.register-strategy('attributes-for', ORM::Factory::AttributesForStrategy);
    ORM::Factory.register-strategy('build-stubbed', ORM::Factory::BuildStubbedStrategy);
  }

  after-each {
    ORM::Factory.unregister-strategy('json');
    ORM::Factory.unregister-strategy('cascade-stub');
    ORM::Factory.register-strategy('build', ORM::Factory::BuildStrategy);
    ORM::Factory.register-strategy('create', ORM::Factory::CreateStrategy);
    ORM::Factory.register-strategy('attributes-for', ORM::Factory::AttributesForStrategy);
    ORM::Factory.register-strategy('build-stubbed', ORM::Factory::BuildStubbedStrategy);
  }

  context 'built-in strategies are pre-registered', {
    it 'exposes the four built-in names', {
      expect(ORM::Factory.strategies.keys.sort.List).to.eq(('attributes-for', 'build', 'build-stubbed', 'create'));
    }

    it 'returns the BuildStrategy class for "build"', {
      expect(ORM::Factory.strategy-class-for('build')).to.be(ORM::Factory::BuildStrategy);
    }

    it 'raises X::ORM::Factory::UnknownStrategy on an unregistered name', {
      expect({ ORM::Factory.strategy-class-for('ghost') }).to.raise-error(X::ORM::Factory::UnknownStrategy);
    }
  }

  context 'register-strategy', {
    before-each {
      ORM::Factory.register-strategy('json', JsonStrategy);

      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'hi';
          .body:  'there';
        };
      };
    }

    it 'adds the new strategy to the registry', {
      expect(ORM::Factory.strategies<json>).to.be(JsonStrategy);
    }

    it 'returns a configured instance via strategy-for', {
      expect(ORM::Factory.strategy-for('json')).to.be-a(JsonStrategy);
    }

    it 'wires :persistence into the registered strategy instance', {
      expect(ORM::Factory.strategy-for('json').persistence).to.be(ORM::Factory.persistence);
    }
  }

  context 'top-level helper dispatch via FALLBACK', {
    before-each {
      ORM::Factory.register-strategy('json', JsonStrategy);

      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'hi';
          .body:  'there';
        };
      };
    }

    it 'invokes the strategy via the registered name', {
      expect(ORM::Factory.json('note')).to.eq('JSON:body=there,title=hi');
    }

    it 'forwards positional variants and named overrides', {
      ORM::Factory.reload;
      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'hi';
          .body:  'there';
          .variant: 'shout', { .title: 'HEY' };
        };
      };
      expect(ORM::Factory.json('note', 'shout', :body<wow>)).to.eq('JSON:body=wow,title=HEY');
    }

    it 'raises X::ORM::Factory::UsageError for an unknown method name', {
      expect({ ORM::Factory.bogus('note') }).to.raise-error(X::ORM::Factory::UsageError);
    }

    it 'raises X::ORM::Factory::UsageError when no factory name is given', {
      ORM::Factory.register-strategy('json', JsonStrategy);
      expect({ ORM::Factory.json }).to.raise-error(X::ORM::Factory::UsageError);
    }
  }

  context 're-registering a built-in name', {
    before-each {
      ORM::Factory.register-strategy('build', ShoutBuildStrategy);
      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'hi';
          .body:  'there';
        };
      };
    }

    it 'overrides the built-in dispatch from ORM::Factory.build', {
      expect(ORM::Factory.build('note').title).to.eq('HI');
    }

    it 'restoring the original class restores the built-in behaviour', {
      ORM::Factory.register-strategy('build', ORM::Factory::BuildStrategy);
      expect(ORM::Factory.build('note').title).to.eq('hi');
    }
  }

  context 'per-strategy association cascade', {
    before-each {
      ORM::Factory.register-strategy('cascade-stub', StubAssocStrategy);

      ORM::Factory.define: {
        .factory: 'note', :aliases<author>, {
          .title: 'a';
          .body:  'b';
        };

        .factory: 'article', {
          .title: 'p';
          .author;
        };
      };
    }

    it 'the strategy controls how associations are built', {
      my $instance = ORM::Factory.cascade-stub('article');
      expect($instance.author).to.be-a(Note);
    }

    it 'the cascade-stub-built association is unsaved (build-stubbed adapter)', {
      my $instance = ORM::Factory.cascade-stub('article');
      expect($instance.author.saved).to.be-falsy;
    }
  }

  context 'role contract', {
    it 'a custom strategy must implement to-sym', {
      expect(JsonStrategy.new(:persistence(ORM::Factory::Persistence::Generic.new)).to-sym).to.eq('json');
    }

    it 'a custom strategy must implement result', {
      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'a';
          .body:  'b';
        };
      };
      ORM::Factory.register-strategy('json', JsonStrategy);
      expect(ORM::Factory.json('note').starts-with('JSON:')).to.be-truthy;
    }

    it 'a custom strategy must implement association', {
      ORM::Factory.define: {
        .factory: 'note', {
          .title: 'x';
          .body:  'y';
        };
      };
      ORM::Factory.register-strategy('cascade-stub', StubAssocStrategy);
      my $s = StubAssocStrategy.new(:persistence(ORM::Factory::Persistence::Generic.new));
      expect($s.association('note', [], {})).to.be-a(Note);
    }
  }
}
