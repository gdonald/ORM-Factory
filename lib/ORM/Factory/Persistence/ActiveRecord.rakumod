use v6.d;
use ORM::Factory::Persistence;

unit class ORM::Factory::Persistence::ActiveRecord does ORM::Factory::Persistence;

my atomicint $STUB-COUNTER = 0;

sub is-ar-model(Mu $instance --> Bool) {
  so $instance.^can('is-persisted')
    && so $instance.^can('is-new-record')
    && so $instance.^can('save-bang')
    && so $instance.^can('attrs');
}

method instantiate(Mu $class, %attrs) {
  if $class.^can('build') {
    return $class.build(%attrs);
  }
  $class.new(|%attrs);
}

method persist(Mu $instance) {
  if $instance.^can('save-bang') {
    $instance.save-bang;
  } elsif $instance.^can('save') {
    $instance.save;
  } else {
    die "no save / save-bang method on {$instance.^name}";
  }
  $instance;
}

method is-valid(Mu $instance --> Bool) {
  $instance.^can('is-valid') ?? $instance.is-valid !! True;
}

method errors(Mu $instance) {
  return Empty unless $instance.^can('errors');

  my $errs = $instance.errors;
  return Empty without $errs;

  if $errs.^can('errors') {
    return $errs.errors.map(-> $e {
      my $field-name = $e.^can('field')   ?? $e.field.name      !! '';
      my $message    = $e.^can('message') ?? $e.message         !! ~$e;
      $field-name ?? "$field-name $message" !! $message;
    }).list;
  }
  $errs.list;
}

method primary-key(Mu $class --> Str) {
  $class.^can('primary-key') ?? $class.primary-key !! 'id';
}

method stub(Mu $instance) {
  return $instance unless is-ar-model($instance);

  my $next = ++$STUB-COUNTER;
  $instance.id = $next;

  my $now = DateTime.now;
  if $instance.^can('attrs') {
    my %a := $instance.attrs;
    %a<created_at> //= $now unless %a<created_at>;
    %a<updated_at> //= $now unless %a<updated_at>;
  }

  if $instance.^can('is-readonly') {
    $instance.is-readonly = True;
  }

  $instance;
}

method reset-stub-counter(--> Nil) {
  $STUB-COUNTER ⚛= 0;
}
