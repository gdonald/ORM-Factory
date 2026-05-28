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

class Sequence {
  has Str      $.name;
  has          $.start = 1;
  has Callable $.block;
  has Iterator $.iterator;
  has          $!current;

  method next {
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

  method rewind(--> Nil) {
    $!current = Nil;
  }
}

sub camelize(Str:D $name --> Str) {
  $name.split(/<[\-_]>+/, :skip-empty).map(*.tc).join;
}

sub resolve-class(Str:D $name --> Mu) {
  return GLOBAL::{$name} if GLOBAL::{$name}:exists;
  Mu;
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
  has %.overrides;
  has %!cache;
  has Mu        $.instance is rw;
  has           $.strategy is rw;

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
    return $!strategy unless $override-name.defined;
    return ORM::Factory.strategy-for($override-name);
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

  method FALLBACK($name, |c) {
    self.value-for($name);
  }
}

class VariantDefinition {
  has Str       $.name;
  has Attribute @.attributes;
}

class FactoryDefinition {
  has Str       $.name;
  has Str       $.class-name;
  has Mu        $.class;
  has Attribute @.attributes;
  has           %.variants;
  has Str       @.applied-variants;
  has Str       @.aliases;
  has           $.parent-name;
  has Bool      $.explicit-class = False;

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
  has           %.variants;
  has Str       @.applied-variants;
  has Bool      $!in-transient = False;
  has           $.parent-name;
  has Bool      $.explicit-class = False;
  has           $.parent-factory;
  has           @.children;

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
    %!variants{$name} = VariantDefinition.new(:$name, :attributes($vb.attributes));
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
      :variants(%!variants),
      :applied-variants(@!applied-variants),
      :aliases(@!aliases),
      :$!parent-name,
      :$!explicit-class,
    );
  }
}

class DefinitionBuilder {
  has %.factories;
  has @.factories-order;
  has %.local-aliases;
  has %.sequences;
  has @.sequences-order;

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

my Bool $ALLOW-CLASS-LOOKUP = True;
my %FACTORIES;
my %ALIASES;
my %SEQUENCES;

method allow-class-lookup(--> Bool) { $ALLOW-CLASS-LOOKUP }

method set-allow-class-lookup(Bool:D $b --> Nil) { $ALLOW-CLASS-LOOKUP = $b }

method define(&block --> Nil) {
  my $db = DefinitionBuilder.new;
  $db.run(&block);

  for $db.sequences-order -> $name {
    die X::ORM::Factory::DuplicateSequence.new(
      message => "sequence '$name' already defined"
    ) if %SEQUENCES{$name}:exists;
    %SEQUENCES{$name} = $db.sequences{$name};
  }

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

    %FACTORIES{$name} = FactoryDefinition.new(
      :name($existing.name),
      :class-name($existing.class-name),
      :class($existing.class),
      :parent-name($existing.parent-name),
      :explicit-class($existing.explicit-class),
      :attributes(@new-attrs),
      :variants(%new-variants),
      :applied-variants(@new-applied),
      :aliases($existing.aliases),
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
  %FACTORIES = ();
  %ALIASES   = ();
  %SEQUENCES = ();
}

method sequences(--> Hash) { %SEQUENCES }

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

sub merge-variants(FactoryDefinition $factory, @runtime-variants --> Array) {
  my @chain = resolve-chain($factory);

  my @attrs;
  for @chain -> $f {
    for $f.attributes.list -> $a {
      @attrs = @attrs.grep(*.name ne $a.name).Array;
      @attrs.push: $a;
    }
  }

  my @applied;
  for @chain -> $f { @applied.append: $f.applied-variants.list }
  @applied.append: @runtime-variants;

  for @applied -> $vname {
    my $variant = find-variant-in-chain($factory, $vname);
    die X::ORM::Factory::UnknownVariant.new(
      message => "no variant '$vname' on factory '{$factory.name}'"
    ) without $variant;

    for $variant.attributes.list -> $a {
      @attrs = @attrs.grep(*.name ne $a.name).Array;
      @attrs.push: $a;
    }
  }

  @attrs;
}

sub build-evaluator(FactoryDefinition $factory, @variants, %overrides --> Evaluator) {
  Evaluator.new(
    :$factory,
    :effective-attributes(merge-variants($factory, @variants)),
    :%overrides,
  );
}

sub is-implicit-association(Str:D $name --> Bool) {
  (%FACTORIES{$name}:exists) || (%ALIASES{$name}:exists);
}

sub build-association($strategy, Str:D $name, @variants, %overrides) {
  $strategy.association($name, @variants, %overrides);
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
    my $instance = $!persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
    $eval.instance = $instance;
    $instance;
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build($name, |@variants, |%overrides);
  }
}

class CreateStrategy does Strategy {
  method to-sym(--> Str) { 'create' }
  method result(Evaluator $eval) {
    my $instance = $!persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
    $eval.instance = $instance;
    $!persistence.persist($instance);
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
    my $instance = $!persistence.instantiate($eval.factory.lookup-class, $eval.attributes-hash);
    $eval.instance = $instance;
    $!persistence.stub($instance);
  }
  method association(Str:D $name, @variants, %overrides) {
    ORM::Factory.build-stubbed($name, |@variants, |%overrides);
  }
}

method strategy-for(Str:D $name) {
  given $name {
    when 'build'          { BuildStrategy.new(:persistence(self.persistence))         }
    when 'create'         { CreateStrategy.new(:persistence(self.persistence))        }
    when 'build-stubbed'  { BuildStubbedStrategy.new(:persistence(self.persistence))  }
    when 'attributes-for' { AttributesForStrategy.new(:persistence(self.persistence)) }
    default {
      die X::ORM::Factory::UsageError.new(
        message => "unknown strategy '$name' (use build/create/build-stubbed/attributes-for)"
      );
    }
  }
}

my @BUILD-CHAIN;

method !run-strategy(Strategy:D $strategy, Str:D $name, @variants, %overrides) {
  my $factory = self.factory-by-name($name);

  if @BUILD-CHAIN.first({ $_ eq $factory.name }).defined {
    my @full = (|@BUILD-CHAIN, $factory.name);
    die X::ORM::Factory::CyclicAssociation.new(
      message => "cyclic association detected building '{$factory.name}' (chain: {@full.join(' -> ')})"
    );
  }

  my $eval    = build-evaluator($factory, @variants, %overrides);
  $eval.strategy = $strategy;

  @BUILD-CHAIN.push: $factory.name;
  my $result;
  {
    $result = $strategy.result($eval);
    CATCH {
      default {
        @BUILD-CHAIN.pop;
        .rethrow;
      }
    }
  }
  @BUILD-CHAIN.pop;
  $result;
}

method build(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(BuildStrategy.new(:persistence(self.persistence)), $name, @variants, %overrides);
}

method create(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(CreateStrategy.new(:persistence(self.persistence)), $name, @variants, %overrides);
}

method attributes-for(Str:D $name, *@variants, *%overrides --> Hash) {
  self!run-strategy(AttributesForStrategy.new(:persistence(self.persistence)), $name, @variants, %overrides);
}

method build-stubbed(Str:D $name, *@variants, *%overrides) {
  self!run-strategy(BuildStubbedStrategy.new(:persistence(self.persistence)), $name, @variants, %overrides);
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
  my $ar-loaded = try { require ::('ORM::Factory::Persistence::ActiveRecord'); True };
  if $ar-loaded {
    my $ar-class = ::('ORM::Factory::Persistence::ActiveRecord');
    return $ar-class.new;
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
