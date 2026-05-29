use v6.d;
use ORM::Factory::Persistence;
use ORM::Factory::Persistence::Generic;

unit class ORM::Factory;

class X::ORM::Factory is Exception {
  has Str $.message;
}

class X::ORM::Factory::UnknownFactory   is X::ORM::Factory {}
class X::ORM::Factory::DuplicateFactory is X::ORM::Factory {}
class X::ORM::Factory::DuplicateVariant is X::ORM::Factory {}
class X::ORM::Factory::UnknownVariant   is X::ORM::Factory {}
class X::ORM::Factory::DuplicateAlias   is X::ORM::Factory {}
class X::ORM::Factory::UnknownClass     is X::ORM::Factory {}
class X::ORM::Factory::UnknownAttribute is X::ORM::Factory {}
class X::ORM::Factory::UnknownSequence  is X::ORM::Factory {}
class X::ORM::Factory::DuplicateSequence is X::ORM::Factory {}
class X::ORM::Factory::UsageError       is X::ORM::Factory {}
class X::ORM::Factory::MissingAssociation is X::ORM::Factory {}
class X::ORM::Factory::CyclicAssociation  is X::ORM::Factory {}
class X::ORM::Factory::UnknownCallback    is X::ORM::Factory {}
class X::ORM::Factory::UnknownStrategy    is X::ORM::Factory {}
class X::ORM::Factory::DuplicateStrategy  is X::ORM::Factory {}
class X::ORM::Factory::InvalidRecord      is X::ORM::Factory {
  has Mu $.record;
  has    @.errors;
  has Str $.factory-name;
}

class X::ORM::Factory::LintFailures is X::ORM::Factory {
  has @.failures;
}

class Sequence {
  has Str      $.name;
  has          $.start = 1;
  has Callable $.block;
  has Iterator $.iterator;
  has          $!current;
  has Lock     $!lock = Lock.new;

  method next {
    $!lock.protect: {
      if $!iterator.defined {
        my $value = $!iterator.pull-one;
        die X::ORM::Factory::UsageError.new(
          message => "sequence '$!name' iterator exhausted"
        ) if $value =:= IterationEnd;
        return $!block.defined ?? $!block.($value) !! $value;
      }

      $!current = $!start unless $!current.defined;
      my $input = $!current;
      $!current = $!current ~~ Numeric ?? $!current + 1 !! $!current.succ;
      $!block.defined ?? $!block.($input) !! $input;
    }
  }

  method rewind(--> Nil) {
    $!lock.protect: { $!current = Nil }
  }
}

sub camelize(Str:D $name --> Str) {
  $name.split(/<[\-_]>+/, :skip-empty).map(*.tc).join;
}

sub resolve-class(Str:D $name --> Mu) {
  return GLOBAL::{$name} if GLOBAL::{$name}:exists;
  Mu;
}

class Callback {
  has Str      $.event;
  has Callable $.block;
}

class Attribute {
  has Str      $.name;
  has Bool     $.dynamic;
  has Bool     $.transient   = False;
  has Bool     $.association = False;
  has Bool     $.has-value   = False;
  has Str      $.factory-name;
  has          @.assoc-variants;
  has          %.assoc-overrides;
  has Str      $.assoc-strategy;
  has Mu       $.value;
  has Callable $.block;
}

class Evaluator {
  has $.factory;
  has Attribute @.effective-attributes;
  has Callback  @.callbacks;
  has %.overrides;
  has %!cache;
  has Mu        $.instance is rw;
  has           $.strategy is rw;

  method run-callbacks(Str:D $event --> Nil) {
    for @!callbacks.grep(*.event eq $event) -> $cb {
      my $b = $cb.block;
      my $count = $b.signature.count;

      given $count {
        when 0  { $b.() }
        when 1  { $b.($!instance) }
        default { $b.($!instance, self) }
      }
    }
  }

  method value-for(Str:D $name) {
    return %!cache{$name} if %!cache{$name}:exists;

    if %!overrides{$name}:exists {
      my $v = %!overrides{$name};
      return %!cache{$name} = $v ~~ Callable ?? $v.(self) !! $v;
    }

    my $attr = @!effective-attributes.first(*.name eq $name);
    die X::ORM::Factory::UnknownAttribute.new(
      message => "no attribute '$name' on factory '{$!factory.name}'"
    ) without $attr;

    if $attr.association {
      return %!cache{$name} = self!resolve-association($attr);
    }

    if !$attr.dynamic && !$attr.has-value && is-implicit-association($attr.name) {
      return %!cache{$name} = self!resolve-implicit-association($attr.name);
    }

    %!cache{$name} = $attr.dynamic
      ?? $attr.block.(self)
      !! $attr.value;
  }

  method !resolve-association(Attribute:D $attr) {
    my $factory-name = $attr.factory-name // $attr.name;
    die X::ORM::Factory::MissingAssociation.new(
      message => "association '{$attr.name}' on factory '{$!factory.name}' targets unknown factory '$factory-name'"
    ) unless ORM::Factory.factory-exists($factory-name);

    my $strategy = self!pick-strategy($attr.assoc-strategy);
    build-association($strategy, $factory-name, $attr.assoc-variants, $attr.assoc-overrides);
  }

  method !resolve-implicit-association(Str:D $name) {
    my $strategy = self!pick-strategy(Str);
    build-association($strategy, $name, [], {});
  }

  method !pick-strategy($override-name) {
    return ORM::Factory.strategy-for($override-name) if $override-name.defined;
    return $!strategy if ORM::Factory.use-parent-strategy;
    ORM::Factory.strategy-for('create');
  }

  method has-value(Str:D $name --> Bool) {
    %!overrides{$name}:exists ||
      @!effective-attributes.first(*.name eq $name).defined;
  }

  method attributes-hash(Bool :$skip-associations = False --> Hash) {
    my %out;
    for @!effective-attributes -> $attr {
      next if $attr.transient;
      if $skip-associations {
        next if $attr.association;
        next if !$attr.dynamic && !$attr.has-value && is-implicit-association($attr.name);
      }
      %out{$attr.name} = self.value-for($attr.name);
    }
    for %!overrides.kv -> $k, $v {
      next if %out{$k}:exists;
      %out{$k} = self.value-for($k);
    }
    %out;
  }

  method attributes(--> Hash) { self.attributes-hash }

  method FALLBACK($name, |c) {
    self.value-for($name);
  }
}

class VariantDefinition {
  has Str       $.name;
  has Attribute @.attributes;
  has Callback  @.callbacks;
}

class FactoryDefinition {
  has Str       $.name;
  has Str       $.class-name;
  has Mu        $.class;
  has Attribute @.attributes;
  has Callback  @.callbacks;
  has           %.variants;
  has Str       @.applied-variants;
  has Str       @.aliases;
  has           $.parent-name;
  has Bool      $.explicit-class = False;
  has Callable  $.initialize-with;
  has Callable  $.to-create;
  has Bool      $.skip-create;

  method lookup-class(--> Mu) {
    return $!class if $!class.^name ne 'Mu' && $!class.^name ne 'Any';

    if $!parent-name.defined && !$!explicit-class {
      return resolve-parent-class(self);
    }

    my $found = resolve-class($!class-name);
    die X::ORM::Factory::UnknownClass.new(
      message => "factory '$!name' resolves to class '$!class-name', but no such class is in scope (declare it, pass :class explicitly, or set ORM::Factory.allow-class-lookup = False)"
    ) if $found.^name eq 'Mu' || $found.^name eq 'Any';
    $found;
  }
}

class FactoryBuilder {
  has Str       $.name;
  has Str       $.class-name;
  has Mu        $.class;
  has Str       @.aliases;
  has Attribute @.attributes;
  has Callback  @.callbacks;
  has           %.variants;
  has Str       @.applied-variants;
  has Bool      $!in-transient = False;
  has           $.parent-name;
  has Bool      $.explicit-class = False;
  has           $.parent-factory;
  has           @.children;
  has Callable  $.initialize-with-block is rw;
  has Callable  $.to-create-block       is rw;
  has Bool      $.skip-create-flag      is rw;

  method add-attribute(Str:D $name, |c --> Nil) {
    my @pos = c.list;
    die X::ORM::Factory::UsageError.new(
      message => "attribute '$name' takes 0 or 1 positional argument, got {@pos.elems}"
    ) if @pos.elems > 1;

    my $transient = $!in-transient;

    if @pos.elems == 0 {
      @!attributes.push: Attribute.new(:$name, :!dynamic, :!has-value, :$transient);
      return;
    }

    my $arg = @pos[0];
    if $arg ~~ Callable {
      @!attributes.push: Attribute.new(:$name, :dynamic, :has-value, :$transient, :block($arg));
    } else {
      @!attributes.push: Attribute.new(:$name, :!dynamic, :has-value, :$transient, :value($arg));
    }
  }

  method association(Str:D $name, *@pos, *%opts --> Nil) {
    my $factory-name = (%opts<factory>:exists) ?? %opts<factory>.Str !! $name;
    my $strategy     = (%opts<strategy>:exists) ?? %opts<strategy>.Str !! Str;

    my @variants = @pos.map(*.Str);

    my %overrides;
    for %opts.kv -> $k, $v {
      next if $k eq 'factory' || $k eq 'strategy';
      %overrides{$k} = $v;
    }

    @!attributes.push: Attribute.new(
      :$name,
      :!dynamic,
      :has-value,
      :association,
      :factory-name($factory-name),
      :assoc-variants(@variants),
      :assoc-overrides(%overrides),
      :assoc-strategy($strategy),
      :transient($!in-transient),
    );
  }

  method transient(&block --> Nil) {
    $!in-transient = True;
    LEAVE { $!in-transient = False }
    block(self);
  }

  method sequence(Str:D $name, &block?, :$start = 1, Iterator :$iterator --> Nil) {
    my $seq = Sequence.new(
      :$name,
      :$start,
      :block(&block),
      :$iterator,
    );
    @!attributes.push: Attribute.new(
      :$name,
      :dynamic,
      :block({ $seq.next }),
    );
  }

  method variant(Str:D $name, &block --> Nil) {
    die X::ORM::Factory::DuplicateVariant.new(
      message => "variant '$name' already defined in factory '$!name'"
    ) if %!variants{$name}:exists;

    my $vb = FactoryBuilder.new(:$name);
    $vb.run(&block);
    %!variants{$name} = VariantDefinition.new(
      :$name,
      :attributes($vb.attributes),
      :callbacks($vb.callbacks),
    );
  }

  method before(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:event("before-$event"), :&block);
  }

  method after(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:event("after-$event"), :&block);
  }

  method callback(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:$event, :&block);
  }

  method initialize-with(&block --> Nil) {
    $!initialize-with-block = &block;
  }

  method to-create(&block --> Nil) {
    $!to-create-block = &block;
  }

  method skip-create(--> Nil) {
    $!skip-create-flag = True;
  }

  method variants-for-enum(Str:D $attr-name, @values --> Nil) {
    for @values -> $v {
      my $vname = $v.Str;
      my $vval  = $v;
      self.variant($vname, -> $vb {
        $vb.add-attribute($attr-name, $vval);
      });
    }
  }

  method factory(Str:D $name, &block, *%opts --> Nil) {
    @!children.push: { :$name, :&block, :%opts };
  }

  method run(&block --> Nil) {
    block(self);
  }

  method has-variant(Str:D $name --> Bool) {
    return True if %!variants{$name}:exists;
    my $cur = $!parent-factory;
    while $cur.defined {
      return True if $cur.variants{$name}:exists;
      my $pn = $cur.parent-name;
      last without $pn;
      $cur = lookup-factory-by-name($pn);
    }
    False;
  }

  method FALLBACK($name, |c --> Nil) {
    if self.has-variant($name) {
      die X::ORM::Factory::UsageError.new(
        message => "variant '$name' applied with arguments; bare .$name; applies a registered variant"
      ) if c.list.elems || c.hash.elems;
      @!applied-variants.push: $name;
      return;
    }

    self.add-attribute($name, |c);
  }

  method compile(--> FactoryDefinition) {
    FactoryDefinition.new(
      :$!name,
      :$!class-name,
      :class($!class),
      :attributes(@!attributes),
      :callbacks(@!callbacks),
      :variants(%!variants),
      :applied-variants(@!applied-variants),
      :aliases(@!aliases),
      :$!parent-name,
      :$!explicit-class,
      :initialize-with($!initialize-with-block),
      :to-create($!to-create-block),
      :skip-create($!skip-create-flag),
    );
  }
}

class DefinitionBuilder {
  has %.factories;
  has @.factories-order;
  has %.local-aliases;
  has %.sequences;
  has @.sequences-order;
  has %.variants;
  has @.variants-order;
  has Callback @.callbacks;
  has Callable $.global-initialize-with is rw;
  has Callable $.global-to-create       is rw;
  has Bool     $.global-skip-create     is rw;

  method before(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:event("before-$event"), :&block);
  }

  method after(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:event("after-$event"), :&block);
  }

  method callback(Str:D $event, &block --> Nil) {
    @!callbacks.push: Callback.new(:$event, :&block);
  }

  method initialize-with(&block --> Nil) {
    $!global-initialize-with = &block;
  }

  method to-create(&block --> Nil) {
    $!global-to-create = &block;
  }

  method skip-create(--> Nil) {
    $!global-skip-create = True;
  }

  method sequence(Str:D $name, &block?, :$start = 1, Iterator :$iterator --> Nil) {
    die X::ORM::Factory::DuplicateSequence.new(
      message => "sequence '$name' already defined"
    ) if %!sequences{$name}:exists;

    %!sequences{$name} = Sequence.new(
      :$name,
      :$start,
      :block(&block),
      :$iterator,
    );
    @!sequences-order.push: $name;
  }

  method variant(Str:D $name, &block --> Nil) {
    die X::ORM::Factory::DuplicateVariant.new(
      message => "global variant '$name' already defined"
    ) if %!variants{$name}:exists;

    my $vb = FactoryBuilder.new(:$name);
    $vb.run(&block);
    %!variants{$name} = VariantDefinition.new(
      :$name,
      :attributes($vb.attributes),
    );
    @!variants-order.push: $name;
  }

  method resolve-parent-factory(Str:D $parent) {
    my $real = %!local-aliases{$parent} // $parent;
    return %!factories{$real} if %!factories{$real}:exists;

    my $global-real = lookup-alias($parent) // $parent;
    lookup-factory-by-name($global-real);
  }

  method factory(Str:D $name, &block, Mu :$class = Mu, :$aliases, :$parent --> Nil) {
    die X::ORM::Factory::DuplicateFactory.new(
      message => "factory '$name' already defined"
    ) if %!factories{$name}:exists;

    my @aliases = $aliases.defined
      ?? ($aliases ~~ Positional ?? $aliases.list.map(*.Str) !! ($aliases.Str,))
      !! ();

    my $class-name = camelize($name);
    my $explicit-class = $class !=== Mu;

    my $resolved-class = Mu;
    if $explicit-class {
      $resolved-class = $class;
    } elsif !$parent.defined && ORM::Factory.allow-class-lookup {
      $resolved-class = resolve-class($class-name);
    }

    my $parent-factory;
    if $parent.defined {
      $parent-factory = self.resolve-parent-factory($parent);
      die X::ORM::Factory::UnknownFactory.new(
        message => "parent factory '$parent' for '$name' is not defined"
      ) without $parent-factory;
    }

    my $fb = FactoryBuilder.new(
      :$name,
      :$class-name,
      :class($resolved-class),
      :@aliases,
      :parent-name($parent),
      :$explicit-class,
      :$parent-factory,
    );
    $fb.run(&block);
    %!factories{$name} = $fb.compile;
    @!factories-order.push: $name;

    for @aliases -> $a {
      %!local-aliases{$a} = $name;
    }

    for $fb.children.list -> %child {
      self.factory(%child<name>, %child<block>, |%child<opts>, :parent($name));
    }
  }

  method run(&block --> Nil) {
    block(self);
  }
}

class ModifyBuilder {
  has @.updates;

  method factory(Str:D $name, &block --> Nil) {
    my $existing = lookup-factory-by-name($name);
    die X::ORM::Factory::UnknownFactory.new(
      message => "no factory named '$name' to modify"
    ) without $existing;

    my $fb = FactoryBuilder.new(
      :name($existing.name),
      :class-name($existing.class-name),
      :class($existing.class),
      :parent-name($existing.parent-name),
      :explicit-class($existing.explicit-class),
      :parent-factory($existing.parent-name.defined
        ?? lookup-factory-by-name($existing.parent-name) !! Nil),
    );
    $fb.run(&block);

    die X::ORM::Factory::UsageError.new(
      message => "cannot define nested factories inside modify"
    ) if $fb.children.elems;

    @!updates.push: { :existing($existing), :fb($fb) };
  }

  method run(&block --> Nil) {
    block(self);
  }
}

class ConfigBuilder {
  method allow-class-lookup(Bool:D $b = True --> Nil) {
    ORM::Factory.set-allow-class-lookup($b);
  }

  method use-parent-strategy(Bool:D $b = True --> Nil) {
    ORM::Factory.set-use-parent-strategy($b);
  }

  method initialize-with(&block --> Nil) {
    ORM::Factory.set-global-initialize-with(&block);
  }

  method to-create(&block --> Nil) {
    ORM::Factory.set-global-to-create(&block);
  }

  method skip-create(Bool:D $b = True --> Nil) {
    ORM::Factory.set-global-skip-create($b);
  }

  method persistence(ORM::Factory::Persistence:D $p --> Nil) {
    ORM::Factory.set-persistence($p);
  }

  method definition-file-paths(*@paths --> Nil) {
    ORM::Factory.set-definition-file-paths(|@paths);
  }

  method register-strategy(Str:D $name, Mu $class --> Nil) {
    ORM::Factory.register-strategy($name, $class);
  }

  method run(&block --> Nil) { block(self) }
}

my Bool $ALLOW-CLASS-LOOKUP    = True;
my Bool $USE-PARENT-STRATEGY   = True;
my Str  @DEFINITION-FILE-PATHS = ('factories.raku', 'spec/factories', 'specs/factories', 'test/factories', 't/factories');
my %FACTORIES;
my %ALIASES;
my %SEQUENCES;
my %GLOBAL-VARIANTS;
my Callback @GLOBAL-CALLBACKS;
my Callable $GLOBAL-INITIALIZE-WITH;
my Callable $GLOBAL-TO-CREATE;
my Bool     $GLOBAL-SKIP-CREATE;
my Lock     $REGISTRY-LOCK = Lock.new;

method allow-class-lookup(--> Bool) { $ALLOW-CLASS-LOOKUP }

method set-allow-class-lookup(Bool:D $b --> Nil) { $ALLOW-CLASS-LOOKUP = $b }

method use-parent-strategy(--> Bool) { $USE-PARENT-STRATEGY }

method set-use-parent-strategy(Bool:D $b --> Nil) { $USE-PARENT-STRATEGY = $b }

method definition-file-paths { @DEFINITION-FILE-PATHS.list }

method set-definition-file-paths(*@paths --> Nil) {
  @DEFINITION-FILE-PATHS = @paths.map(*.Str);
}

method set-global-initialize-with(&block --> Nil) { $GLOBAL-INITIALIZE-WITH = &block }

method set-global-to-create(&block --> Nil) { $GLOBAL-TO-CREATE = &block }

method set-global-skip-create(Bool:D $b --> Nil) { $GLOBAL-SKIP-CREATE = $b }

method configure(&block --> Nil) {
  my $cb = ConfigBuilder.new;
  $cb.run(&block);
}

method define(&block --> Nil) {
  $REGISTRY-LOCK.protect: { self!define-locked(&block) }
}

method !define-locked(&block --> Nil) {
  my $db = DefinitionBuilder.new;
  $db.run(&block);

  for $db.sequences-order -> $name {
    die X::ORM::Factory::DuplicateSequence.new(
      message => "sequence '$name' already defined"
    ) if %SEQUENCES{$name}:exists;
    %SEQUENCES{$name} = $db.sequences{$name};
  }

  for $db.variants-order -> $name {
    die X::ORM::Factory::DuplicateVariant.new(
      message => "global variant '$name' already defined"
    ) if %GLOBAL-VARIANTS{$name}:exists;
    %GLOBAL-VARIANTS{$name} = $db.variants{$name};
  }

  for $db.callbacks.list -> $cb {
    @GLOBAL-CALLBACKS.push: $cb;
  }

  $GLOBAL-INITIALIZE-WITH = $db.global-initialize-with with $db.global-initialize-with;
  $GLOBAL-TO-CREATE       = $db.global-to-create       with $db.global-to-create;
  $GLOBAL-SKIP-CREATE     = $db.global-skip-create     with $db.global-skip-create;

  for $db.factories-order -> $name {
    my $def = $db.factories{$name};

    die X::ORM::Factory::DuplicateFactory.new(
      message => "factory '$name' already defined"
    ) if %FACTORIES{$name}:exists;

    die X::ORM::Factory::DuplicateAlias.new(
      message => "factory name '$name' collides with an existing alias"
    ) if %ALIASES{$name}:exists;

    for $def.aliases -> $alias {
      die X::ORM::Factory::DuplicateAlias.new(
        message => "alias '$alias' (on factory '$name') collides with an existing factory"
      ) if %FACTORIES{$alias}:exists;

      die X::ORM::Factory::DuplicateAlias.new(
        message => "alias '$alias' (on factory '$name') collides with an existing alias for '%ALIASES{$alias}'"
      ) if %ALIASES{$alias}:exists;
    }

    %FACTORIES{$name} = $def;
    for $def.aliases -> $alias {
      %ALIASES{$alias} = $name;
    }
  }
}

method modify(&block --> Nil) {
  $REGISTRY-LOCK.protect: { self!modify-locked(&block) }
}

method !modify-locked(&block --> Nil) {
  my $mb = ModifyBuilder.new;
  $mb.run(&block);

  for $mb.updates.list -> %u {
    my $existing = %u<existing>;
    my $fb       = %u<fb>;
    my $name     = $existing.name;

    my @new-attrs = $existing.attributes.list.Array;
    for $fb.attributes.list -> $a {
      @new-attrs = @new-attrs.grep(*.name ne $a.name).Array;
      @new-attrs.push: $a;
    }

    my %new-variants = $existing.variants;
    for $fb.variants.kv -> $k, $v { %new-variants{$k} = $v }

    my @new-applied = $existing.applied-variants.list.Array;
    for $fb.applied-variants.list -> $av {
      @new-applied.push: $av;
    }

    my Callback @new-callbacks = (|$existing.callbacks.list, |$fb.callbacks.list);

    %FACTORIES{$name} = FactoryDefinition.new(
      :name($existing.name),
      :class-name($existing.class-name),
      :class($existing.class),
      :parent-name($existing.parent-name),
      :explicit-class($existing.explicit-class),
      :attributes(@new-attrs),
      :callbacks(@new-callbacks),
      :variants(%new-variants),
      :applied-variants(@new-applied),
      :aliases($existing.aliases),
      :initialize-with($fb.initialize-with-block // $existing.initialize-with),
      :to-create($fb.to-create-block            // $existing.to-create),
      :skip-create($fb.skip-create-flag         // $existing.skip-create),
    );
  }
}

method factories(--> Hash) { %FACTORIES }

method aliases(--> Hash) { %ALIASES }

method factory-by-name(Str:D $name --> FactoryDefinition) {
  my $real = %ALIASES{$name} // $name;
  die X::ORM::Factory::UnknownFactory.new(
    message => "no factory named '$name'"
  ) unless %FACTORIES{$real}:exists;
  %FACTORIES{$real};
}

method factory-exists(Str:D $name --> Bool) {
  (%FACTORIES{$name}:exists) || (%ALIASES{$name}:exists);
}

method reload(--> Nil) {
  $REGISTRY-LOCK.protect: {
    %FACTORIES        = ();
    %ALIASES          = ();
    %SEQUENCES        = ();
    %GLOBAL-VARIANTS  = ();
    @GLOBAL-CALLBACKS = ();
    $GLOBAL-INITIALIZE-WITH = Callable;
    $GLOBAL-TO-CREATE       = Callable;
    $GLOBAL-SKIP-CREATE     = Bool;
    $USE-PARENT-STRATEGY    = True;
    @DEFINITION-FILE-PATHS  = ('factories.raku', 'spec/factories', 'specs/factories', 'test/factories', 't/factories');
  }
}

method find-definitions(--> Nil) {
  for @DEFINITION-FILE-PATHS -> $p {
    my $io = $p.IO;
    next unless $io.e;
    if $io.f {
      EVALFILE $io.absolute;
    } elsif $io.d {
      for $io.dir.grep({ .f && (.extension eq 'raku' || .extension eq 'rakumod') }).sort -> $f {
        EVALFILE $f.absolute;
      }
    }
  }
}

method global-initialize-with { $GLOBAL-INITIALIZE-WITH }

method global-to-create       { $GLOBAL-TO-CREATE       }

method global-skip-create     { $GLOBAL-SKIP-CREATE     }

method global-callbacks(--> Array) { @GLOBAL-CALLBACKS }

method sequences(--> Hash) { %SEQUENCES }

method variants(--> Hash) { %GLOBAL-VARIANTS }

method factory-names(--> List) { %FACTORIES.keys.sort.List }

method sequence-names(--> List) { %SEQUENCES.keys.sort.List }

method global-variant-names(--> List) { %GLOBAL-VARIANTS.keys.sort.List }

method variant-names-for(Str:D $name --> List) {
  my $factory = self.factory-by-name($name);
  my @names;
  for resolve-chain($factory) -> $f {
    @names.append: $f.variants.keys.list;
  }
  @names.unique.sort.List;
}

method dump-attributes(Str:D $name, *@variants, *%overrides --> Hash) {
  my $factory = self.factory-by-name($name);
  my $eval    = build-evaluator($factory, @variants, %overrides);
  my %dump;
  for $eval.effective-attributes -> $attr {
    my %entry =
      :transient($attr.transient),
      :association($attr.association),
      :dynamic($attr.dynamic),
      :has-value($attr.has-value);
    %entry<factory-name> = $attr.factory-name if $attr.association;
    %dump{$attr.name} = %entry;
  }
  %dump;
}

method describe-factory(Str:D $name --> Hash) {
  my $factory = self.factory-by-name($name);
  my @chain   = resolve-chain($factory).map(*.name);
  {
    :name($factory.name),
    :class-name($factory.class-name),
    :parent($factory.parent-name),
    :ancestors(@chain.List),
    :aliases($factory.aliases.List),
    :variants($factory.variants.keys.sort.List),
    :attributes(self.dump-attributes($name)),
  };
}

method lint(*@factory-names, Str :$strategy = 'create', Bool :$variants = False, Bool :$verbose = False --> Nil) {
  my @to-lint = @factory-names ?? @factory-names.map(*.Str) !! %FACTORIES.keys.sort;
  my @failures;

  for @to-lint -> $name {
    self.factory-by-name($name);
    my @combos = ('',);
    if $variants {
      @combos = ('', |self.variant-names-for($name));
    }

    for @combos -> $vname {
      my $label = $vname ?? "$name+$vname" !! $name;
      say "lint: $label ..." if $verbose;
      try {
        my @args = $vname ?? ($vname,) !! ();
        my $instance = self."$strategy"($name, |@args);

        if $instance.defined && self.persistence.^can('is-valid') {
          unless self.persistence.is-valid($instance) {
            die X::ORM::Factory::InvalidRecord.new(
              message => "validation failed for '$label'",
              :record($instance),
              :factory-name($name),
              :errors(self.persistence.errors($instance).list),
            );
          }
        }

        say "lint: $label OK" if $verbose;
        CATCH {
          default {
            say "lint: $label FAIL ({.message})" if $verbose;
            @failures.push: %( :factory($name), :variant($vname), :error(.message) );
          }
        }
      }
    }
  }

  if @failures {
    my @lines = "lint failed for {@failures.elems} factor{ @failures.elems == 1 ?? 'y' !! 'ies' }:";
    for @failures -> $f {
      my $label = $f<factory>;
      $label ~= " (variant: {$f<variant>})" if $f<variant>;
      @lines.push: "  - $label: {$f<error>}";
    }
    die X::ORM::Factory::LintFailures.new(
      :message(@lines.join("\n")),
      :failures(@failures),
    );
  }
}

method generate(Str:D $name) {
  die X::ORM::Factory::UnknownSequence.new(
    message => "no sequence named '$name'"
  ) unless %SEQUENCES{$name}:exists;
  %SEQUENCES{$name}.next;
}

method generate-list(Str:D $name, Int:D $count) {
  (^$count).map({ self.generate($name) }).Array;
}

method rewind-sequences(--> Nil) {
  for %SEQUENCES.values -> $seq { $seq.rewind }
}

sub lookup-alias(Str:D $name) {
  %ALIASES{$name}:exists ?? %ALIASES{$name} !! Nil;
}

sub lookup-factory-by-name(Str:D $name) {
  return %FACTORIES{$name} if %FACTORIES{$name}:exists;
  my $aliased = %ALIASES{$name};
  return Nil unless $aliased.defined;
  return %FACTORIES{$aliased} if %FACTORIES{$aliased}:exists;
  Nil;
}

sub resolve-parent-class(FactoryDefinition $factory --> Mu) {
  return Mu unless $factory.parent-name.defined;
  my $parent = lookup-factory-by-name($factory.parent-name);
  die X::ORM::Factory::UnknownFactory.new(
    message => "factory '{$factory.name}' has parent '{$factory.parent-name}' which is not defined"
  ) without $parent;
  $parent.lookup-class;
}

sub resolve-chain(FactoryDefinition $factory --> Array) {
  my @chain = $factory,;
  my $cur = $factory;
  while $cur.parent-name.defined {
    my $parent = lookup-factory-by-name($cur.parent-name);
    die X::ORM::Factory::UnknownFactory.new(
      message => "factory '{$cur.name}' has parent '{$cur.parent-name}' which is not defined"
    ) without $parent;
    @chain.unshift($parent);
    $cur = $parent;
  }
  @chain;
}

sub find-variant-in-chain(FactoryDefinition $factory, Str:D $name) {
  for resolve-chain($factory).reverse -> $f {
    return $f.variants{$name} if $f.variants{$name}:exists;
  }
  Nil;
}

sub find-variant-anywhere(FactoryDefinition $factory, Str:D $name) {
  my $local = find-variant-in-chain($factory, $name);
  return $local with $local;
  %GLOBAL-VARIANTS{$name}:exists ?? %GLOBAL-VARIANTS{$name} !! Nil;
}

sub is-known-variant(FactoryDefinition $factory, Str:D $name --> Bool) {
  find-variant-anywhere($factory, $name).defined;
}

sub split-bare-variant-refs(FactoryDefinition $factory, @input --> List) {
  my @attrs;
  my @bare-applied;
  for @input -> $a {
    if !$a.dynamic && !$a.has-value && !$a.association
         && is-known-variant($factory, $a.name) {
      @bare-applied.push: $a.name;
    } else {
      @attrs.push: $a;
    }
  }
  (@attrs, @bare-applied);
}

sub merge-variants(FactoryDefinition $factory, @runtime-variants --> List) {
  my @chain = resolve-chain($factory);

  my @attrs;
  my Callback @callbacks;
  for @chain -> $f {
    for $f.attributes.list -> $a {
      @attrs = @attrs.grep(*.name ne $a.name).Array;
      @attrs.push: $a;
    }
    @callbacks.append: $f.callbacks.list;
  }

  my ($keep, $bare-applied) = split-bare-variant-refs($factory, @attrs);
  @attrs = $keep.list;

  my @applied;
  for @chain -> $f { @applied.append: $f.applied-variants.list }
  @applied.append: $bare-applied.list;
  @applied.append: @runtime-variants;

  sub apply-variant-rec(Str:D $vname, @cycle is copy) {
    return if @cycle.first(* eq $vname).defined;
    @cycle.push: $vname;

    my $variant = find-variant-anywhere($factory, $vname);
    die X::ORM::Factory::UnknownVariant.new(
      message => "no variant '$vname' on factory '{$factory.name}'"
    ) without $variant;

    my ($v-attrs, $v-bare-applied) = split-bare-variant-refs($factory, $variant.attributes);

    for $v-bare-applied.list -> $nested {
      apply-variant-rec($nested, @cycle);
    }

    for $v-attrs.list -> $a {
      @attrs = @attrs.grep(*.name ne $a.name).Array;
      @attrs.push: $a;
    }

    @callbacks.append: $variant.callbacks.list;
  }

  for @applied -> $vname {
    apply-variant-rec($vname, []);
  }

  (@attrs, @callbacks);
}

sub build-evaluator(FactoryDefinition $factory, @variants, %overrides --> Evaluator) {
  my ($attrs, $cbs) = merge-variants($factory, @variants);
  my Callback @effective-callbacks = (|@GLOBAL-CALLBACKS, |$cbs.list);

  Evaluator.new(
    :$factory,
    :effective-attributes($attrs.list),
    :callbacks(@effective-callbacks),
    :%overrides,
  );
}

sub is-implicit-association(Str:D $name --> Bool) {
  (%FACTORIES{$name}:exists) || (%ALIASES{$name}:exists);
}

sub build-association($strategy, Str:D $name, @variants, %overrides) {
  $strategy.association($name, @variants, %overrides);
}

sub resolve-initialize-with(FactoryDefinition $factory) {
  for resolve-chain($factory).reverse -> $f {
    return $f.initialize-with if $f.initialize-with.defined;
  }
  $GLOBAL-INITIALIZE-WITH;
}

sub resolve-create-hook(FactoryDefinition $factory --> List) {
  for resolve-chain($factory).reverse -> $f {
    return ('custom', $f.to-create) if $f.to-create.defined;
    return ('skip', Callable)       if $f.skip-create;
  }
  return ('custom', $GLOBAL-TO-CREATE)   if $GLOBAL-TO-CREATE.defined;
  return ('skip',   Callable)            if $GLOBAL-SKIP-CREATE;
  ('default', Callable);
}

sub instantiate-with-hook(ORM::Factory::Persistence $persistence, Evaluator $eval) {
  my $hook = resolve-initialize-with($eval.factory);
  return $hook.($eval) if $hook.defined;
  $persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
}

sub persist-with-hook(ORM::Factory::Persistence $persistence, Evaluator $eval, $instance --> Nil) {
  my ($kind, $hook) = resolve-create-hook($eval.factory);
  given $kind {
    when 'custom'  { $hook.($instance, $eval) }
    when 'skip'    { }
    default        { $persistence.persist($instance) }
  }
}

role Strategy {
  has ORM::Factory::Persistence $.persistence;

  method to-sym(--> Str) { ... }
  method result(Evaluator $eval) { ... }
  method association(Str:D $name, @variants, %overrides) { ... }
}

class BuildStrategy does Strategy {
  method to-sym(--> Str) { 'build' }
  method result(Evaluator $eval) {
    my $instance = instantiate-with-hook($!persistence, $eval);
    $eval.instance = $instance;
    $eval.run-callbacks('after-build');
    $instance;
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build($name, |@variants, |%overrides);
  }
}

class CreateStrategy does Strategy {
  method to-sym(--> Str) { 'create' }
  method result(Evaluator $eval) {
    my $instance = instantiate-with-hook($!persistence, $eval);
    $eval.instance = $instance;
    $eval.run-callbacks('after-build');
    $eval.run-callbacks('before-create');
    persist-with-hook($!persistence, $eval, $instance);
    $eval.run-callbacks('after-create');
    $instance;
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.create($name, |@variants, |%overrides);
  }
}

class AttributesForStrategy does Strategy {
  method to-sym(--> Str) { 'attributes-for' }
  method result(Evaluator $eval) { $eval.attributes-hash(:skip-associations) }
  method association(Str:D $name, @variants, %overrides) {
    Nil;
  }
}

class BuildStubbedStrategy does Strategy {
  method to-sym(--> Str) { 'build-stubbed' }
  method result(Evaluator $eval) {
    my $instance = instantiate-with-hook($!persistence, $eval);
    $eval.instance = $instance;
    my $stubbed = $!persistence.stub($instance);
    $eval.instance = $stubbed;
    $eval.run-callbacks('after-stub');
    $stubbed;
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build-stubbed($name, |@variants, |%overrides);
  }
}

my %STRATEGIES;

sub init-builtin-strategies(--> Nil) {
  return if %STRATEGIES;
  %STRATEGIES<build>          = BuildStrategy;
  %STRATEGIES<create>         = CreateStrategy;
  %STRATEGIES<build-stubbed>  = BuildStubbedStrategy;
  %STRATEGIES<attributes-for> = AttributesForStrategy;
}

method strategies(--> Hash) {
  init-builtin-strategies();
  %STRATEGIES;
}

method strategy-class-for(Str:D $name) {
  init-builtin-strategies();
  die X::ORM::Factory::UnknownStrategy.new(
    message => "no strategy named '$name' (registered: {%STRATEGIES.keys.sort.join(', ')})"
  ) unless %STRATEGIES{$name}:exists;
  %STRATEGIES{$name};
}

method strategy-for(Str:D $name) {
  self.strategy-class-for($name).new(:persistence(self.persistence));
}

method register-strategy(Str:D $name, Mu $strategy-class --> Nil) {
  init-builtin-strategies();
  %STRATEGIES{$name} = $strategy-class;
}

method unregister-strategy(Str:D $name --> Nil) {
  init-builtin-strategies();
  %STRATEGIES{$name}:delete;
}

method !run-strategy(Strategy:D $strategy, Str:D $name, @variants, %overrides) {
  my $factory = self.factory-by-name($name);

  my @*BUILD-CHAIN = (CALLERS::<@*BUILD-CHAIN> // ()).Array;
  if @*BUILD-CHAIN.first({ $_ eq $factory.name }).defined {
    my @full = (|@*BUILD-CHAIN, $factory.name);
    die X::ORM::Factory::CyclicAssociation.new(
      message => "cyclic association detected building '{$factory.name}' (chain: {@full.join(' -> ')})"
    );
  }

  my $eval    = build-evaluator($factory, @variants, %overrides);
  $eval.strategy = $strategy;

  @*BUILD-CHAIN.push: $factory.name;
  $strategy.result($eval);
}

method FALLBACK(Str:D $name, |c) {
  init-builtin-strategies();

  die X::ORM::Factory::UsageError.new(
    message => "no method '$name' on ORM::Factory (registered strategies: {%STRATEGIES.keys.sort.join(', ')})"
  ) unless %STRATEGIES{$name}:exists;

  my @positional = c.list;
  my %named      = c.hash;

  die X::ORM::Factory::UsageError.new(
    message => "strategy '$name' requires a factory name as the first argument"
  ) unless @positional.elems >= 1;

  my $factory-name = @positional.shift.Str;
  my @variants     = @positional.map(*.Str);

  self!run-strategy(self.strategy-for($name), $factory-name, @variants, %named);
}

method build(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(self.strategy-for('build'), $name, @variants, %overrides);
}

method create(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(self.strategy-for('create'), $name, @variants, %overrides);
}

method attributes-for(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(self.strategy-for('attributes-for'), $name, @variants, %overrides);
}

method build-stubbed(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(self.strategy-for('build-stubbed'), $name, @variants, %overrides);
}

method build-list(Str:D $name, Int:D $count, *@rest, *%overrides) {
  my @variants = @rest;
  my $block;
  $block = @variants.pop if @variants && @variants[*-1] ~~ Callable;

  my @out;
  for ^$count -> $i {
    my $instance = self.build($name, |@variants, |%overrides);
    $block.($instance, $i) with $block;
    @out.push: $instance;
  }
  @out;
}

method create-list(Str:D $name, Int:D $count, *@rest, *%overrides) {
  my @variants = @rest;
  my $block;
  $block = @variants.pop if @variants && @variants[*-1] ~~ Callable;

  my @out;
  for ^$count -> $i {
    my $instance = self.create($name, |@variants, |%overrides);
    $block.($instance, $i) with $block;
    @out.push: $instance;
  }
  @out;
}

method build-stubbed-list(Str:D $name, Int:D $count, *@rest, *%overrides) {
  my @variants = @rest;
  my $block;
  $block = @variants.pop if @variants && @variants[*-1] ~~ Callable;

  my @out;
  for ^$count -> $i {
    my $instance = self.build-stubbed($name, |@variants, |%overrides);
    $block.($instance, $i) with $block;
    @out.push: $instance;
  }
  @out;
}

method attributes-for-list(Str:D $name, Int:D $count, *@variants, *%overrides) {
  my @out;
  for ^$count {
    @out.push: self.attributes-for($name, |@variants, |%overrides);
  }
  @out;
}

method build-pair(Str:D $name, *@rest, *%overrides) {
  self.build-list($name, 2, |@rest, |%overrides);
}

method create-pair(Str:D $name, *@rest, *%overrides) {
  self.create-list($name, 2, |@rest, |%overrides);
}

my ORM::Factory::Persistence $PERSISTENCE;

sub detect-persistence(--> ORM::Factory::Persistence) {
  my $ar-available = try { require ::('ORM::ActiveRecord::Model'); True };
  if $ar-available {
    my $loaded = try { require ::('ORM::Factory::Persistence::ActiveRecord'); True };
    if $loaded {
      my $ar-class = ::('ORM::Factory::Persistence::ActiveRecord');
      return $ar-class.new;
    }
  }
  ORM::Factory::Persistence::Generic.new;
}

method persistence(--> ORM::Factory::Persistence) {
  $PERSISTENCE //= detect-persistence();
  $PERSISTENCE;
}

method set-persistence(ORM::Factory::Persistence $p --> Nil) {
  $PERSISTENCE = $p;
}

method reset-persistence(--> Nil) {
  $PERSISTENCE = ORM::Factory::Persistence;
}
