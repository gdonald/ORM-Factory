use lib 'lib';
use BDD::Behave;
use ORM::Factory;

describe 'sequences', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(False);
  }

  after-each { ORM::Factory.set-allow-class-lookup(True); }

  context 'global sequence with a block', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'email', -> $n { "user{$n}\@example.com" };
      };
    }

    it 'generates the first value', {
      expect(ORM::Factory.generate('email')).to.eq('user1@example.com');
    }

    it 'increments on each call', {
      ORM::Factory.generate('email');
      expect(ORM::Factory.generate('email')).to.eq('user2@example.com');
    }

    it 'generate-list returns N successive values', {
      my @list = ORM::Factory.generate-list('email', 3);
      expect(@list).to.eq(['user1@example.com', 'user2@example.com', 'user3@example.com']);
    }
  }

  context 'sequence without a block returns the raw counter', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'counter';
      };
    }

    it 'first call returns 1', {
      expect(ORM::Factory.generate('counter')).to.be(1);
    }

    it 'second call returns 2', {
      ORM::Factory.generate('counter');
      expect(ORM::Factory.generate('counter')).to.be(2);
    }
  }

  context 'custom numeric start', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'id', :start(1000);
      };
    }

    it 'starts at the given value', {
      expect(ORM::Factory.generate('id')).to.be(1000);
    }

    it 'increments from the start', {
      ORM::Factory.generate('id');
      expect(ORM::Factory.generate('id')).to.be(1001);
    }
  }

  context 'custom string start uses .succ', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'letter', :start('a');
      };
    }

    it 'starts at the given letter', {
      expect(ORM::Factory.generate('letter')).to.eq('a');
    }

    it 'advances by .succ', {
      ORM::Factory.generate('letter');
      expect(ORM::Factory.generate('letter')).to.eq('b');
    }
  }

  context 'rewind-sequences resets every counter', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'a';
        .sequence: 'b';
      };
      ORM::Factory.generate('a');
      ORM::Factory.generate('a');
      ORM::Factory.generate('b');
      ORM::Factory.rewind-sequences;
    }

    it 'sequence a starts over', {
      expect(ORM::Factory.generate('a')).to.be(1);
    }

    it 'sequence b starts over', {
      expect(ORM::Factory.generate('b')).to.be(1);
    }
  }

  context 'unknown sequence', {
    it 'raises X::ORM::Factory::UnknownSequence', {
      expect({ ORM::Factory.generate('ghost') }).to.throw(X::ORM::Factory::UnknownSequence);
    }
  }

  context 'duplicate global sequence', {
    it 'raises X::ORM::Factory::DuplicateSequence', {
      expect({
        ORM::Factory.define: {
          .sequence: 'email', -> $n { "a$n" };
        };
        ORM::Factory.define: {
          .sequence: 'email', -> $n { "b$n" };
        };
      }).to.throw(X::ORM::Factory::DuplicateSequence);
    }
  }

  context 'sequence from a custom iterator', {
    before-each {
      ORM::Factory.define: {
        .sequence: 'fib', :iterator((1, 1, *+* ... *).iterator);
      };
    }

    it 'pulls values from the iterator', {
      expect(ORM::Factory.generate-list('fib', 5)).to.eq([1, 1, 2, 3, 5]);
    }
  }

  context 'reload clears sequences', {
    before-each {
      ORM::Factory.define: { .sequence: 'email'; };
      ORM::Factory.reload;
    }

    it 'sequences hash is empty', {
      expect(ORM::Factory.sequences.elems).to.be(0);
    }
  }
}

describe 'inline sequences in a factory', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-allow-class-lookup(False);

    ORM::Factory.define: {
      .factory: 'thing', :class(Hash), {
        .sequence: 'token', -> $n { "tok-$n" };
      };
    };
  }

  after-each { ORM::Factory.set-allow-class-lookup(True); }

  it 'binds the sequence as an attribute on the factory', {
    expect(ORM::Factory.factory-by-name('thing').attributes[0].name).to.eq('token');
  }

  it 'first build produces the first value', {
    expect(ORM::Factory.attributes-for('thing')<token>).to.eq('tok-1');
  }

  it 'second build advances the counter (isolated per factory)', {
    ORM::Factory.attributes-for('thing');
    expect(ORM::Factory.attributes-for('thing')<token>).to.eq('tok-2');
  }
}
