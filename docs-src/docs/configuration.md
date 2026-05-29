# Configuration

`ORM::Factory.configure` is the single entry point for project-wide knobs.
It accepts a builder block; the receiver exposes setters for every supported
option.

```raku
use ORM::Factory;

ORM::Factory.configure: {
  .allow-class-lookup(True);
  .use-parent-strategy(True);
  .persistence(MyAdapter.new);
  .definition-file-paths(<spec/factories specs/factories>);

  .initialize-with: -> $eval { ... };
  .to-create:       -> $instance, $eval { ... };
  .skip-create(False);
};
```

Every option also has a direct setter for code that prefers to skip the
builder:

| option                 | configure call                       | direct setter                              |
| ---------------------- | ------------------------------------ | ------------------------------------------ |
| allow-class-lookup     | `.allow-class-lookup(Bool)`          | `set-allow-class-lookup(Bool)`             |
| use-parent-strategy    | `.use-parent-strategy(Bool)`         | `set-use-parent-strategy(Bool)`            |
| persistence            | `.persistence(Persistence)`          | `set-persistence(Persistence)`             |
| definition-file-paths  | `.definition-file-paths(*@paths)`    | `set-definition-file-paths(*@paths)`       |
| initialize-with        | `.initialize-with(&block)`           | `set-global-initialize-with(&block)`       |
| to-create              | `.to-create(&block)`                 | `set-global-to-create(&block)`             |
| skip-create            | `.skip-create(Bool)`                 | `set-global-skip-create(Bool)`             |

## allow-class-lookup

Toggles class-name resolution from the factory name. With it off,
`factory 'user'` will only resolve a class if you pass `:class(User)`.

## use-parent-strategy

When `True` (the default), an association inherits the surrounding strategy:
`create('post')` cascades `create` to the author, `build('post')` cascades
`build`, etc.

When `False`, associations always default to `create` regardless of the
surrounding strategy — the legacy `factory_bot` behaviour. A per-association
`:strategy(...)` still wins:

```raku
ORM::Factory.configure: { .use-parent-strategy(False) };

ORM::Factory.build('post').author.saved;  # True — author was created
```

## persistence

Installs a specific persistence adapter, overriding auto-detection:

```raku
ORM::Factory.configure: { .persistence(MyAdapter.new) };
```

`reset-persistence` restores auto-detection for the next call.

## Global hooks

`initialize-with`, `to-create`, and `skip-create` are the global versions of
the per-factory [construction hooks](construction.md). They run only when
neither the factory nor any ancestor sets its own hook.

## Loading definitions

`ORM::Factory.find-definitions` walks `definition-file-paths` and
`EVALFILE`s every entry that resolves:

* a file path is loaded directly,
* a directory is scanned for `.raku` / `.rakumod` files (sorted), each
  loaded into the same shared registry,
* a missing path is skipped silently.

```raku
ORM::Factory.set-definition-file-paths('specs/factories');
ORM::Factory.find-definitions;
ORM::Factory.factory-by-name('user');
```

Multiple files defining the same factory will raise
`X::ORM::Factory::DuplicateFactory` (see
[Linting & diagnostics](lint.md)).
