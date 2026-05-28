use v6.d;

unit class ORM::Factory;

class X::ORM::Factory is Exception {
  has Str $.message;
}

class X::ORM::Factory::UnknownFactory   is X::ORM::Factory {}
class X::ORM::Factory::DuplicateFactory is X::ORM::Factory {}
class X::ORM::Factory::DuplicateVariant is X::ORM::Factory {}
class X::ORM::Factory::UsageError       is X::ORM::Factory {}

class Attribute {
  has Str      $.name;
  has Bool     $.dynamic;
  has Mu       $.value;
  has Callable $.block;
}

class VariantDefinition {
  has Str       $.name;
  has Attribute @.attributes;
}

class FactoryDefinition {
  has Str           $.name;
  has Attribute     @.attributes;
  has               %.variants;
  has Str           @.applied-variants;
}

class FactoryBuilder {
  has Str       $.name;
  has Attribute @.attributes;
  has           %.variants;
  has Str       @.applied-variants;

  method add-attribute(Str:D $name, |c --> Nil) {
    my @pos = c.list;
    die X::ORM::Factory::UsageError.new(
      message => "attribute '$name' takes 0 or 1 positional argument, got {@pos.elems}"
    ) if @pos.elems > 1;

    if @pos.elems == 0 {
      @!attributes.push: Attribute.new(:$name, :!dynamic);
      return;
    }

    my $arg = @pos[0];
    if $arg ~~ Callable {
      @!attributes.push: Attribute.new(:$name, :dynamic, :block($arg));
    } else {
      @!attributes.push: Attribute.new(:$name, :!dynamic, :value($arg));
    }
  }

  method variant(Str:D $name, &block --> Nil) {
    die X::ORM::Factory::DuplicateVariant.new(
      message => "variant '$name' already defined in factory '$!name'"
    ) if %!variants{$name}:exists;

    my $vb = FactoryBuilder.new(:$name);
    $vb.run(&block);
    %!variants{$name} = VariantDefinition.new(:$name, :attributes($vb.attributes));
  }

  method run(&block --> Nil) {
    block(self);
  }

  method FALLBACK($name, |c --> Nil) {
    if %!variants{$name}:exists {
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
      :attributes(@!attributes),
      :variants(%!variants),
      :applied-variants(@!applied-variants),
    );
  }
}

class DefinitionBuilder {
  has %.factories;

  method factory(Str:D $name, &block --> Nil) {
    die X::ORM::Factory::DuplicateFactory.new(
      message => "factory '$name' already defined"
    ) if %!factories{$name}:exists;

    my $fb = FactoryBuilder.new(:$name);
    $fb.run(&block);
    %!factories{$name} = $fb.compile;
  }

  method run(&block --> Nil) {
    block(self);
  }
}

my %FACTORIES;

method define(&block --> Nil) {
  my $db = DefinitionBuilder.new;
  $db.run(&block);
  for $db.factories.kv -> $name, $def {
    die X::ORM::Factory::DuplicateFactory.new(
      message => "factory '$name' already defined"
    ) if %FACTORIES{$name}:exists;
    %FACTORIES{$name} = $def;
  }
}

method factories(--> Hash)        { %FACTORIES        }

method factory-by-name(Str:D $name --> FactoryDefinition) {
  die X::ORM::Factory::UnknownFactory.new(
    message => "no factory named '$name'"
  ) unless %FACTORIES{$name}:exists;
  %FACTORIES{$name};
}

method reload(--> Nil) { %FACTORIES = () }
