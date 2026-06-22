use lib 'lib';
use lib 'specs/lib';
use BDD::Behave;
use ORM::Factory;
use Factory::Test::AR;

publish-globals();

describe 'ORM::Factory automatic enum variants', {
  before-each {
    ORM::Factory.reload;
    ORM::Factory.set-automatically-define-enum-variants(True);
    Order.destroy-all;

    define {
      .factory: 'order', :class(Order), -> $ { };
    };
  }

  context 'with the toggle enabled (the default)', {
    it 'derives one build-time variant per enum value', {
      expect(ORM::Factory.build('order', 'shipped').status).to.eq('shipped');
    }

    it 'lists every enum value among the factory variants', {
      expect(ORM::Factory.variant-names-for('order').List).to.eq(('delivered', 'pending', 'shipped'));
    }

    it 'persists the chosen enum value through create', {
      expect(ORM::Factory.create('order', 'delivered').status).to.eq('delivered');
    }

    it 'lets an explicitly declared variant override the derived one', {
      define {
        .factory: 'flagged-order', :class(Order), {
          .variant: 'shipped', {
            .status: 'pending';
          };
        };
      };

      expect(ORM::Factory.build('flagged-order', 'shipped').status).to.eq('pending');
    }
  }

  context 'with the toggle disabled', {
    before-each {
      ORM::Factory.set-automatically-define-enum-variants(False);
    }

    it 'does not derive enum variants', {
      expect({ ORM::Factory.build('order', 'shipped') }).to.raise-error(X::ORM::Factory::UnknownVariant);
    }

    it 'lists no variants for the factory', {
      expect(ORM::Factory.variant-names-for('order').elems).to.eq(0);
    }
  }
}
