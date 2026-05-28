use lib 'lib';
use BDD::Behave;
use ORM::Factory;
use ORM::Factory::Persistence;
use ORM::Factory::Persistence::Generic;

our class PlainWithSaveOrDie {
  has Str $.name is rw;
  has Bool $.saved is rw = False;
  method save-or-die { $!saved = True; self }
}

our class PlainWithSaveOnly {
  has Str $.name is rw;
  has Bool $.saved is rw = False;
  method save { $!saved = True; self }
}

our class PlainNoPersistence {
  has Str $.name is rw;
}

BEGIN GLOBAL::<PlainWithSaveOrDie> := PlainWithSaveOrDie;
BEGIN GLOBAL::<PlainWithSaveOnly>  := PlainWithSaveOnly;
BEGIN GLOBAL::<PlainNoPersistence> := PlainNoPersistence;

describe 'ORM::Factory::Persistence::Generic', {
  my $adapter;
  before-each { $adapter = ORM::Factory::Persistence::Generic.new; }

  context 'role conformance', {
    it 'does the Persistence role', {
      expect($adapter ~~ ORM::Factory::Persistence).to.be-truthy;
    }
  }

  context 'instantiate', {
    it 'builds via Class.new(|%attrs)', {
      my $inst = $adapter.instantiate(PlainWithSaveOrDie, { :name<Greg> });
      expect($inst.name).to.eq('Greg');
    }

    it 'raises a clear error when no class is set', {
      expect({ $adapter.instantiate(Mu, %()) }).to.raise-error;
    }
  }

  context 'persist', {
    it 'prefers save-or-die when available', {
      my $inst = PlainWithSaveOrDie.new(name => 'X');
      $adapter.persist($inst);
      expect($inst.saved).to.be-truthy;
    }

    it 'falls back to save when save-or-die is absent', {
      my $inst = PlainWithSaveOnly.new(name => 'X');
      $adapter.persist($inst);
      expect($inst.saved).to.be-truthy;
    }

    it 'raises a clear error when neither method exists', {
      my $inst = PlainNoPersistence.new(name => 'X');
      expect({ $adapter.persist($inst) }).to.raise-error;
    }
  }

  context 'defaults for optional methods', {
    it 'is-valid defaults to True', {
      expect($adapter.is-valid(PlainNoPersistence.new)).to.be-truthy;
    }

    it 'primary-key defaults to id', {
      expect($adapter.primary-key(PlainNoPersistence)).to.eq('id');
    }
  }
}

describe 'ORM::Factory persistence selection', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(False);
  }

  after-each {
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);
  }

  it 'defaults to the Generic adapter when no AR adapter is installed', {
    expect(ORM::Factory.persistence).to.be-a(ORM::Factory::Persistence::Generic);
  }

  it 'caches the resolved adapter across calls', {
    expect(ORM::Factory.persistence).to.be(ORM::Factory.persistence);
  }

  context 'explicit set-persistence overrides auto-detection', {
    my $custom;
    before-each {
      $custom = ORM::Factory::Persistence::Generic.new;
      ORM::Factory.set-persistence($custom);
    }

    it 'returns the explicitly set adapter', {
      expect(ORM::Factory.persistence).to.be($custom);
    }
  }

  context 'reset-persistence', {
    before-each {
      ORM::Factory.set-persistence(ORM::Factory::Persistence::Generic.new);
      ORM::Factory.reset-persistence;
    }

    it 'restores auto-detection on next access', {
      expect(ORM::Factory.persistence).to.be-a(ORM::Factory::Persistence::Generic);
    }
  }
}
