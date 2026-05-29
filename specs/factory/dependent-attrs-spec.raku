use lib 'lib';
use BDD::Behave;
use ORM::Factory;

# Dependent attributes — at definition time the DSL captures the block
# unchanged. Binding `$_` to the evaluator at build time is the evaluator's
# job (a later milestone); this spec verifies the DSL preserves the block
# so the evaluator has something to call.
describe 'dependent attribute capture', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(False);
  }

  after-each {
    ORM::Factory.set-allow-class-lookup(True);
  }

  context 'a block referencing another attribute via the evaluator topic', {
    before-each {
      define {
        .factory: 'user', {
          .fname: 'Greg';
          .email: { .fname ~ '@example.com' };
        };
      };
    }

    it 'captures the dependent attribute as dynamic', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[1];
      expect($attr.dynamic).to.be-truthy;
    }

    it 'stores the block unchanged', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[1];
      expect($attr.block).to.be-a(Callable);
    }

    it 'invoking the block with a stand-in evaluator resolves the reference', {
      my $attr = ORM::Factory.factory-by-name('user').attributes[1];
      my $eval-stub = class :: { method fname { 'Greg' } }.new;
      expect($attr.block.($eval-stub)).to.eq('Greg@example.com');
    }
  }

  context 'declaration order is preserved through capture', {
    before-each {
      define {
        .factory: 'user', {
          .fname:    'Greg';
          .lname:    'Donald';
          .email:    { .fname ~ '@example.com' };
          .nickname: { .fname.lc };
        };
      };
    }

    it 'preserves the order of dependent and non-dependent attributes', {
      my @names = ORM::Factory.factory-by-name('user').attributes.map(*.name).list;
      expect(@names).to.eq(['fname', 'lname', 'email', 'nickname']);
    }
  }
}
