# ORM::Factory

`ORM::Factory` is a definition DSL for building test objects in Raku, with
or without persistence, so your specs stay declarative.

With [`ORM::ActiveRecord`](https://github.com/gdonald/ORM-ActiveRecord)
installed, `create` calls the model's `save-or-die`. Without an ORM,
factories build plain objects; use `to-create` or `initialize-with` to hook
a different persistence layer.

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

define {
  .factory: 'user', {
    .sequence: 'email', -> $n { "user$n\@example.com" };
    .fname: 'Greg';
    .lname: 'Donald';

    .variant: 'admin', {
      .role: 'admin';
    };
  };
};

my $user  = build('user');                      # unsaved instance
my $saved = create('user');                     # build + persist
my $admin = create('user', 'admin');            # apply the admin variant
my %attrs = attributes-for('user');             # plain attribute hash
my $stub  = build-stubbed('user');              # faked id, no DB access
```

## Build Status

[![CI](https://github.com/gdonald/ORM-Factory/actions/workflows/ci.yml/badge.svg)](https://github.com/gdonald/ORM-Factory/actions/workflows/ci.yml)

### License

Copyright (c) 2026 Greg Donald

This software is licensed under the Artistic License 2.0.

[![GitHub](https://img.shields.io/github/license/gdonald/ORM-Factory?color=aa0000)](https://github.com/gdonald/ORM-Factory/blob/main/LICENSE)
