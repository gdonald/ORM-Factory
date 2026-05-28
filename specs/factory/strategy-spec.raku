use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence::Generic;

describe 'strategy plumbing', {
  my $persistence;
  before-each { $persistence = ORM::Factory::Persistence::Generic.new; }

  context 'to-sym names', {
    it 'BuildStrategy reports build', {
      expect(ORM::Factory::BuildStrategy.new(:$persistence).to-sym).to.eq('build');
    }

    it 'CreateStrategy reports create', {
      expect(ORM::Factory::CreateStrategy.new(:$persistence).to-sym).to.eq('create');
    }

    it 'AttributesForStrategy reports attributes-for', {
      expect(ORM::Factory::AttributesForStrategy.new(:$persistence).to-sym).to.eq('attributes-for');
    }

    it 'BuildStubbedStrategy reports build-stubbed', {
      expect(ORM::Factory::BuildStubbedStrategy.new(:$persistence).to-sym).to.eq('build-stubbed');
    }
  }

  context 'role conformance', {
    it 'BuildStrategy does ORM::Factory::Strategy', {
      expect(ORM::Factory::BuildStrategy.new(:$persistence) ~~ ORM::Factory::Strategy).to.be-truthy;
    }

    it 'AttributesForStrategy does ORM::Factory::Strategy', {
      expect(ORM::Factory::AttributesForStrategy.new(:$persistence) ~~ ORM::Factory::Strategy).to.be-truthy;
    }
  }

  context 'association placeholder', {
    it 'association raises until associations land', {
      expect({
        ORM::Factory::BuildStrategy.new(:$persistence).association('any');
      }).to.throw(X::ORM::Factory::UsageError);
    }
  }
}
