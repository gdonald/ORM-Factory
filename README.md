# ORM::Factory

`ORM::Factory` is a Raku port of Ruby's
[`factory_bot`](https://github.com/thoughtbot/factory_bot) — a definition DSL
for building test objects (with or without persistence) so your specs stay
declarative.

It is ORM-agnostic at its core. With
[`ORM::ActiveRecord`](https://github.com/gdonald/ORM-ActiveRecord) installed
and auto-detected, `create` persists through the model's `save-or-die` with
validations, callbacks, and timestamps intact. With no ORM loaded, factories
still build plain objects, and the `to-create` / `initialize-with` hooks let
you target any persistence layer.

## Documentation

[https://gdonald.github.io/ORM-Factory/](https://gdonald.github.io/ORM-Factory/)

## Install using zef

```
zef install --/test ORM::Factory
```

`--/test` is suggested because the full suite exercises every supported
adapter (PostgreSQL, MySQL, SQLite). The library itself has no runtime
dependencies; `ORM::ActiveRecord` is a `test-depends` and is auto-detected at
runtime when installed.

## First factory

```perl6
use ORM::Factory;

ORM::Factory.define: {
  sequence 'email', -> $n { "user{$n}\@example.com" }

  factory 'user', {
    fname     'Greg'
    lname     'Donald'
    email     { generate('email') }

    variant 'admin', {
      role 'admin'
    }
  }
}

my $user  = build('user');                      # unsaved instance
my $saved = create('user');                     # build + persist
my $admin = create('user', 'admin');            # apply the admin variant
my %attrs = attributes-for('user');             # plain attribute hash
my $stub  = build-stubbed('user');              # faked id, no DB access
```

## Status

`ORM::Factory` is greenfield. See [ROADMAP.md](ROADMAP.md) for the porting
plan and current progress.

## Build Status

[![.github/workflows/raku.yml](https://github.com/gdonald/ORM-Factory/workflows/.github/workflows/raku.yml/badge.svg)](https://github.com/gdonald/ORM-Factory/actions)

### License

Copyright (c) 2026 Greg Donald

This software is licensed under the Artistic License 2.0.

[![GitHub](https://img.shields.io/github/license/gdonald/ORM-Factory?color=aa0000)](https://github.com/gdonald/ORM-Factory/blob/main/LICENSE)
