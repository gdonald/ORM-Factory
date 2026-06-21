use v6.d;
use ORM::Factory::Persistence;

# Duck-typed default adapter used when no ORM-specific adapter is registered.
# It instantiates via `$class.new(|%attrs)`, persists via `.save-bang` (or
# `.save`), and raises a clear error if neither method exists.
unit class ORM::Factory::Persistence::Generic does ORM::Factory::Persistence;

class X::ORM::Factory::Persistence::NoPersistence is Exception {
  has Str $.message;
}

method instantiate(Mu $class, %attrs) {
  die X::ORM::Factory::Persistence::NoPersistence.new(
    message => 'cannot instantiate: factory has no class set (pass :class explicitly or define one in scope)'
  ) if $class.^name eq 'Mu' || $class.^name eq 'Any';

  $class.new(|%attrs);
}

method persist(Mu $instance) {
  if $instance.^can('save-bang') {
    $instance.save-bang;
  } elsif $instance.^can('save') {
    $instance.save;
  } else {
    die X::ORM::Factory::Persistence::NoPersistence.new(
      message => "no save / save-bang method on {$instance.^name}; provide a to-create hook or install an ORM adapter"
    );
  }
  $instance;
}

method is-valid(Mu $instance --> Bool) {
  $instance.^can('is-valid')
    ?? $instance.is-valid
    !! True;
}

method errors(Mu $instance) {
  $instance.^can('errors')
    ?? $instance.errors
    !! Empty;
}

method primary-key(Mu $class --> Str) {
  $class.^can('primary-key')
    ?? $class.primary-key
    !! 'id';
}

method stub(Mu $instance) { $instance }
