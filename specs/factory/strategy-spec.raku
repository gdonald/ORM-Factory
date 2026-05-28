use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence::Generic;

our class Tag {
  has Str $.name is rw;
}

GLOBAL::<Tag> := Tag;

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

  context 'association dispatch', {
    it 'AttributesForStrategy.association returns Nil without persistence', {
      my $result = ORM::Factory::AttributesForStrategy.new(:$persistence).association('tag', [], {});
      expect($result).to.be(Nil);
    }
  }
}
