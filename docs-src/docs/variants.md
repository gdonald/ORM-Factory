# Variants

A **variant** captures a named cluster of attribute, association, or transient
changes that you can layer onto a factory on demand. `factory_bot` calls these
*traits*; the term is the same idea.

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .fname: 'Greg';

    .variant: 'admin', {
      .role: 'admin';
    };
  };
};

ORM::Factory.build('user').role;            # Str (no role)
ORM::Factory.build('user', 'admin').role;   # 'admin'
```

Variants apply through every build strategy — `build`, `create`,
`build-stubbed`, and `attributes-for` — and through the `*-list` /  `*-pair`
helpers.

## Applying variants at build time

Pass variant names as positional arguments to any build strategy:

```perl6
ORM::Factory.build('user', 'admin');
ORM::Factory.create('user', 'admin');
ORM::Factory.build-stubbed('user', 'admin');
ORM::Factory.attributes-for('user', 'admin');
```

The same positional form works for the list helpers:

```perl6
ORM::Factory.build-list('user', 3, 'admin');
ORM::Factory.create-pair('user', 'admin');
```

## Multiple variants apply left-to-right

When several variants set the same attribute, the **last one wins**:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .variant: 'admin', { .role: 'admin' };
    .variant: 'guest', { .role: 'guest' };
  };
};

ORM::Factory.build('user', 'admin', 'guest').role;   # 'guest'
ORM::Factory.build('user', 'guest', 'admin').role;   # 'admin'
```

Non-overlapping attributes from each variant are preserved.

## What a variant can contain

A variant block is a mini factory body. It can declare any of:

- **Static or dynamic attributes** that override the factory's defaults.
- **Associations** via `.association: 'name', :factory<...>`.
- **Transient attributes** via `.transient: { ... }`, which the rest of the
  variant (or the original factory body) can read.

```perl6
ORM::Factory.define: {
  .factory: 'user', { .fname: 'Greg' };

  .factory: 'post', {
    .title: 'Hello';

    .variant: 'authored', {
      .association: 'author', :factory<user>;
    };

    .variant: 'shouty', {
      .transient: { .salute: 'WORLD' };
      .greeting:  { "Hello, {.salute}" };
    };
  };
};
```

## Variants referencing other variants

A variant can apply another variant by bare name. Cycles are detected and
short-circuited, so two variants can safely reference each other:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .variant: 'active', { .status: 'active' };
    .variant: 'admin',  { .active; .role: 'admin' };   # applies :active first
  };
};

ORM::Factory.build('user', 'admin').status;   # 'active'
ORM::Factory.build('user', 'admin').role;     # 'admin'
```

## Composing a factory entirely from variants

Reference variants by bare name in a factory body to layer them in at
definition time:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .fname: 'Greg';
    .variant: 'admin',  { .role: 'admin' };
    .variant: 'active', { .status: 'active' };

    .factory: 'admin-active-user', {
      .admin;
      .active;
    };
  };
};

ORM::Factory.build('admin-active-user').role;     # 'admin'
ORM::Factory.build('admin-active-user').status;   # 'active'
```

The same form works for [global variants](#global-variants), so a top-level
trait can be reused across many factories.

## Variant inheritance

A child factory inherits its parent's variants. Either pre-apply them in the
child body, or pass them at build time:

```perl6
ORM::Factory.define: {
  .factory: 'person', {
    .fname: 'Greg';
    .variant: 'admin', { .role: 'admin' };
  };

  .factory: 'admin-person', :parent('person'), {
    .admin;                                         # pre-applied
  };
};

ORM::Factory.build('admin-person').role;   # 'admin'
```

See the [Inheritance](inheritance.md) page for the full chain rules.

## Parameterised variants

Combine a variant with a transient default to give callers a knob:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .variant: 'greeted', {
      .transient: { .salute: 'World' };
      .greeting:  { "Hello, {.salute}" };
    };
  };
};

ORM::Factory.build('user', 'greeted').greeting;                 # 'Hello, World'
ORM::Factory.build('user', 'greeted', :salute<Greg>).greeting;  # 'Hello, Greg'
```

The transient is excluded from `attributes-for` and never reaches the model
constructor.

## Global variants

A variant declared at the top of an `ORM::Factory.define` block — without a
surrounding `factory` — is **global**. Any factory can apply it, by name at
build time or as a bare reference in its body:

```perl6
ORM::Factory.define: {
  .variant: 'flagged', { .flag: True };

  .factory: 'user', { .fname: 'Greg' };

  .factory: 'flagged-user', :class(User), {
    .fname: 'Greg';
    .flagged;
  };
};

ORM::Factory.build('user', 'flagged').flag;   # True
ORM::Factory.build('flagged-user').flag;      # True
```

`ORM::Factory.variants` returns the registered global variants. Redefining a
global variant raises `X::ORM::Factory::DuplicateVariant`; `ORM::Factory.reload`
clears them along with everything else.

## `variants-for-enum`

`variants-for-enum` declares one variant per value, each one setting the named
attribute to its value:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .variants-for-enum: 'role', <admin guest member>;
  };
};

ORM::Factory.build('user', 'admin').role;    # 'admin'
ORM::Factory.build('user', 'guest').role;    # 'guest'
ORM::Factory.build('user', 'member').role;   # 'member'
```

The value list is explicit; no ORM enum reflection is required. (Automatic
enum variants from an `ORM::ActiveRecord` enum column are gated on AR's enum
support and will arrive in a later phase.)

## Errors

- An unknown variant at build time raises `X::ORM::Factory::UnknownVariant`.
- Defining a variant twice in the same factory raises
  `X::ORM::Factory::DuplicateVariant`.
- Defining a global variant twice raises `X::ORM::Factory::DuplicateVariant`.
- A bare variant reference passed arguments raises
  `X::ORM::Factory::UsageError` — only attribute setters take arguments.
