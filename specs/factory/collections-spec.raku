use lib 'lib';
use BDD::Behave;
use ORM::Factory;

our class Item {
  has Str  $.label  is rw;
  has Str  $.role  is rw;
  has Int  $.index is rw;
  has Bool $.saved is rw = False;
  method save-bang { $!saved = True; self }
}

GLOBAL::<Item> := Item;

describe 'collection build strategies', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.reset-persistence;
    ORM::Factory.set-allow-class-lookup(True);

    define {
      .factory: 'item', {
        .label: 'default';

        .variant: 'admin', {
          .role: 'admin';
        };
      };
    };
  }

  context 'build-list', {
    it 'returns N instances', {
      expect(ORM::Factory.build-list('item', 3).elems).to.be(3);
    }

    it 'each instance has the factory class', {
      expect(ORM::Factory.build-list('item', 2)[0]).to.be-a(Item);
    }

    it 'none are saved', {
      expect(ORM::Factory.build-list('item', 2)[0].saved).to.be-falsy;
    }

    it 'applies a positional variant to every instance', {
      expect(ORM::Factory.build-list('item', 2, 'admin')[0].role).to.eq('admin');
    }

    it 'applies overrides to every instance', {
      expect(ORM::Factory.build-list('item', 2, :label<X>)[1].label).to.eq('X');
    }

    it 'block form runs once per instance with its index', {
      my @list = ORM::Factory.build-list('item', 3, -> $it, $i { $it.index = $i });
      expect(@list.map(*.index).List).to.eq((0, 1, 2));
    }
  }

  context 'create-list', {
    it 'returns N persisted instances', {
      my @list = ORM::Factory.create-list('item', 2);
      expect(@list.map(*.saved).grep(?*).elems).to.be(2);
    }
  }

  context 'build-stubbed-list', {
    it 'returns N stubbed instances', {
      expect(ORM::Factory.build-stubbed-list('item', 2).elems).to.be(2);
    }

    it 'none are saved (Generic adapter)', {
      expect(ORM::Factory.build-stubbed-list('item', 2)[0].saved).to.be-falsy;
    }
  }

  context 'attributes-for-list', {
    it 'returns N hashes', {
      expect(ORM::Factory.attributes-for-list('item', 3).elems).to.be(3);
    }

    it 'each is a Hash with the resolved attributes', {
      expect(ORM::Factory.attributes-for-list('item', 1)[0]<label>).to.eq('default');
    }
  }

  context 'pair shortcuts', {
    it 'build-pair returns two instances', {
      expect(ORM::Factory.build-pair('item').elems).to.be(2);
    }

    it 'create-pair returns two persisted instances', {
      expect(ORM::Factory.create-pair('item')[0].saved).to.be-truthy;
    }

    it 'pair forms accept variants and overrides', {
      my @list = ORM::Factory.build-pair('item', 'admin', :label<X>);
      expect(@list[0].role).to.eq('admin');
    }

    it 'pair forms accept the block form', {
      my @list = ORM::Factory.build-pair('item', -> $it, $i { $it.index = $i });
      expect(@list[1].index).to.be(1);
    }
  }
}
