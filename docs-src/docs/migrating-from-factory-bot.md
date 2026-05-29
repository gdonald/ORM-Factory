# Migrating from factory_bot

`ORM::Factory` is a Raku port of Ruby's
[`factory_bot`](https://github.com/thoughtbot/factory_bot). Most concepts
carry over one-for-one; this page lists the cases where the spelling
changed.

## Module and DSL entry point

| factory_bot                | ORM::Factory                       |
|----------------------------|------------------------------------|
| `FactoryBot.define { ... }`| `ORM::Factory.define: { ... }`     |
| `FactoryBot.modify { ... }`| `ORM::Factory.modify: { ... }`     |
| `FactoryBot.lint`          | `ORM::Factory.lint`                |
| `factory :user do ... end` | `.factory: 'user', { ... }`        |

Names are Raku strings, not Ruby symbols: `build(:user)` becomes
`build('user')`.

## Method-name conventions

Ruby snake_case becomes Raku kebab-case:

| factory_bot         | ORM::Factory          |
|---------------------|-----------------------|
| `build_stubbed`     | `build-stubbed`       |
| `attributes_for`    | `attributes-for`      |
| `to_create`         | `to-create`           |
| `initialize_with`   | `initialize-with`     |
| `skip_create`       | `skip-create`         |
| `rewind_sequences`  | `rewind-sequences`    |
| `register_strategy` | `register-strategy`   |

Ruby `!` becomes `-or-die`; Ruby `?` becomes `is-`:

| factory_bot     | ORM::Factory   |
|-----------------|----------------|
| `save!`         | `save-or-die`  |
| `persisted?`    | `is-persisted` |
| `new_record?`   | `is-new-record`|
| `valid?`        | `is-valid`     |

## Traits / variants

`factory_bot`'s **trait** is renamed **variant** throughout, partly to free up
the word "trait" (which means something specific in Raku) and partly because
"variant" reads more clearly:

| factory_bot               | ORM::Factory            |
|---------------------------|-------------------------|
| `trait :admin do ... end` | `.variant: 'admin', { ... }` |
| `traits_for_enum :status` | `.variants-for-enum: 'status', @values` |

## Blocks

Ruby blocks with block-locals become Raku pointy blocks:

```ruby
sequence(:email) { |n| "user#{n}@example.com" }
```

```perl6
.sequence: 'email', -> $n { "user{$n}\@example.com" };
```

## Class lookup

`factory_bot` infers the model class from the factory name and an `class:`
option lets you override it. `ORM::Factory` does the same, but the toggle is
explicit:

```perl6
.factory: 'admin', :class(User), { ... };
ORM::Factory.set-allow-class-lookup(False);   # turn off auto-resolution
```

## Persistence

`factory_bot` is tightly coupled to ActiveRecord. `ORM::Factory` defers to
the [persistence adapter](persistence.md) protocol; ActiveRecord is one
implementation (auto-detected when loaded). With no ORM installed, the
generic adapter handles plain Raku classes.

`X::RecordInvalid` (raised from `create`) is the AR exception, the
same as `factory_bot`'s `ActiveRecord::RecordInvalid`.

## What is intentionally missing

- **Data generation** — `factory_bot` does not ship a Faker either. Use a
  Raku faker / data-generator next to it (see the [cookbook](cookbook.md)).
- **Linting strategies beyond `build` and `create`** — `factory_bot` lints
  `create` by default; `ORM::Factory` does the same and accepts
  `:strategy<build>` for the same reason.
- **`reload` of definitions on file change** — `ORM::Factory.reload` clears
  the registry, but there is no file-watcher; you re-run
  `find-definitions` yourself.

## A side-by-side example

```ruby
# factory_bot
FactoryBot.define do
  sequence(:email) { |n| "user#{n}@example.com" }

  factory :user do
    fname { "Greg" }
    email { generate(:email) }

    trait :admin do
      role { "admin" }
    end
  end

  factory :post do
    title { "Hello" }
    author factory: :user, role: "admin"
  end
end

FactoryBot.create(:user, :admin)
FactoryBot.build_stubbed(:post)
```

```perl6
# ORM::Factory
ORM::Factory.define: {
  .sequence: 'email', -> $n { "user{$n}\@example.com" };

  .factory: 'user', {
    .fname: 'Greg';
    .email: { ORM::Factory.generate('email') };

    .variant: 'admin', {
      .role: 'admin';
    };
  };

  .factory: 'post', {
    .title: 'Hello';
    .association: 'author', :factory<user>, 'admin';
  };
};

ORM::Factory.create('user', 'admin');
ORM::Factory.build-stubbed('post');
```
