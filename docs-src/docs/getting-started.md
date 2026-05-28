# Getting started

This page walks you through defining your first factory, reading it back from
the registry, and resetting state between tests. The build strategies
(`build`, `create`, `attributes-for`, `build-stubbed`) come in later
milestones — see the [ROADMAP](https://github.com/gdonald/ORM-Factory/blob/main/ROADMAP.md).

## Install

```
zef install --/test ORM::Factory
```

## Defining a factory

`ORM::Factory.define` opens a definition block. Inside, the topic (`$_`) is
bound to a `DefinitionBuilder`, so DSL calls use the leading-dot shorthand:

```perl6
use ORM::Factory;

ORM::Factory.define: {
  .factory: 'user', {
    .fname: 'Greg';
    .lname: 'Donald';
    .email: { 'user@example.com' };
  };
};
```

A *static* attribute takes any non-`Callable` value: `.fname: 'Greg'`. A
*dynamic* attribute takes a single `Callable` and is evaluated lazily:
`.email: { 'user@example.com' }`.

## Reading the registry

Definitions land in a process-global registry keyed by name:

```perl6
my %factories = ORM::Factory.factories;        # all definitions
my $user      = ORM::Factory.factory-by-name('user');

say $user.name;                                 # 'user'
say $user.attributes.elems;                     # 3
say $user.attributes[0].name;                   # 'fname'
say $user.attributes[0].value;                  # 'Greg'
```

Looking up an unregistered name raises `X::ORM::Factory::UnknownFactory`.

## Variants

A *variant* (the term `factory_bot` calls a "trait") is an alternate set of
overrides scoped to one factory. Define one with `.variant`, apply it inside
the same factory body with a bare leading-dot call:

```perl6
ORM::Factory.define: {
  .factory: 'user', {
    .fname: 'Greg';

    .variant: 'admin', {
      .role: 'admin';
    };

    .admin;
  };
};
```

The `.admin` call resolves against the registered variant name first. If the
name isn't a registered variant, it falls back to capturing an attribute
named `admin`.

## Names that collide with the DSL

DSL method names — `factory`, `variant`, `transient`, `association`,
`add-attribute`, `before`, `after`, `initialize-with`, `to-create`, `modify`,
`skip-create` — cannot be captured by the FALLBACK shortcut. Use the explicit
`add-attribute` escape hatch:

```perl6
.add-attribute: 'factory', 'acme';   # attribute literally named "factory"
.add-attribute: 'block',   -> { 42 };  # a Callable literal as a static value
```

`add-attribute` skips the FALLBACK indirection and stores exactly what you
pass: a `Callable` arg is treated as dynamic, anything else as static, with
no chance of colliding with a method name on the builder.

## Resetting between tests

`ORM::Factory.reload` clears the registry. Run it before each test to keep
suites from leaking definitions:

```perl6
use BDD::Behave;
use ORM::Factory;

describe 'my feature', {
  before-each {
    ORM::Factory.reload;
  }

  # …
};
```

For `prove6`, just call `ORM::Factory.reload` at the top of each test block.
See [Tests](tests.md) for the full convention.

## Diagnostics

The library raises typed exceptions under `X::ORM::Factory::*`:

| Exception                            | Trigger                                      |
|--------------------------------------|----------------------------------------------|
| `X::ORM::Factory::UnknownFactory`    | `factory-by-name` on an unregistered name.   |
| `X::ORM::Factory::DuplicateFactory`  | Two `.factory 'x', …` calls with the same name. |
| `X::ORM::Factory::DuplicateVariant`  | Two `.variant 'x', …` calls in the same factory. |
| `X::ORM::Factory::UsageError`        | Argument shape the DSL can't make sense of (e.g. a variant applied with arguments). |
