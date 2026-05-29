use v6.d;
use ORM::Factory;

unit module ORM::Factory::Methods;

sub build(Str:D $name, |c) is export {
  ORM::Factory.build($name, |c);
}

sub create(Str:D $name, |c) is export {
  ORM::Factory.create($name, |c);
}

sub build-stubbed(Str:D $name, |c) is export {
  ORM::Factory.build-stubbed($name, |c);
}

sub attributes-for(Str:D $name, |c) is export {
  ORM::Factory.attributes-for($name, |c);
}

sub build-list(Str:D $name, Int:D $count, |c) is export {
  ORM::Factory.build-list($name, $count, |c);
}

sub create-list(Str:D $name, Int:D $count, |c) is export {
  ORM::Factory.create-list($name, $count, |c);
}

sub build-stubbed-list(Str:D $name, Int:D $count, |c) is export {
  ORM::Factory.build-stubbed-list($name, $count, |c);
}

sub attributes-for-list(Str:D $name, Int:D $count, |c) is export {
  ORM::Factory.attributes-for-list($name, $count, |c);
}

sub build-pair(Str:D $name, |c) is export {
  ORM::Factory.build-pair($name, |c);
}

sub create-pair(Str:D $name, |c) is export {
  ORM::Factory.create-pair($name, |c);
}

sub generate(Str:D $name) is export {
  ORM::Factory.generate($name);
}

sub generate-list(Str:D $name, Int:D $count) is export {
  ORM::Factory.generate-list($name, $count);
}
