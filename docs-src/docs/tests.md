# Tests

`ORM::Factory` ships a parallel `t/` and `specs/` tree. Both contain the same
coverage; `t/` is the canonical prove6 suite (kept while ecosystem tooling
still expects it), and `specs/` is the BDD-style suite run by
[`behave`](https://github.com/gdonald/BDD-Behave). Long-term the `t/` tree
will be retired in favour of `specs/`.

## Running the suite

`./test.raku` is the canonical entry point. It runs the unit pass first
(DB-agnostic) and then cycles through PostgreSQL, MySQL, and SQLite — probing
each first and skipping unreachable adapters with a message describing how to
enable them. With `DATABASE_URL` set it runs once against that adapter (this
is what CI does per matrix entry).

```shell
$ ./test.raku
```

When all three adapters are reachable you get a runtimes summary at the end:

```shell
==> Runtimes
  unit         6.94s
  postgres     3.49s
  mysql        3.47s
  sqlite       3.49s
  total       17.55s
```

To pick a subset of adapters, pass `--adapter`:

```shell
$ ./test.raku --adapter=pg
$ ./test.raku --adapter=mysql,sqlite
```

## Running with prove6 or behave directly

To run the prove6 suite once against your default adapter:

```shell
$ prove6 -Ilib t
```

To run a single behave spec file:

```shell
$ behave specs/factory/dsl-spec.raku
```

## Layout convention: `t/` ↔ `specs/` mirroring

Every test file in `t/` has a corresponding spec in `specs/` and vice versa.
Shared code (helpers, sample data, parsers reused by both) lives in
`specs/lib/` and is added to the path by `test.raku`. The mirroring is a hard
rule, not an aspiration:

- a new behaviour gets one `t/.../*.rakutest` and one `specs/.../*-spec.raku`;
- shared scaffolding (model classes, parse helpers) goes in `specs/lib/Factory/Test/...`;
- the spec/test runner (`test.raku`) treats both trees as first-class.

## Layout convention: `db/` vs unit pass

Inside both trees, a test or spec that needs a live database lives under the
tree's top-level `db/` (`t/db/**`, `specs/db/**`) and is run once per
reachable adapter with `DATABASE_URL` set and migrations applied. Everything
else is DB-agnostic and runs once in the "unit" pass with no database.

The marker is the *leading path segment*. `specs/db/connection-spec.raku` is
DB-backed; a `db` folder nested deeper (`specs/model/db/...`) is not.

## Configuring the database

`./test.raku` picks a URL per adapter from, in order:

1. `DATABASE_URL` (if set, that single URL is used and no probing is done);
2. `FACTORY_PG_URL`, `FACTORY_MYSQL_URL`, `FACTORY_SQLITE_URL` (per-adapter overrides);
3. `config/application.json` (the `test` environment's primary connection
   supplies the database name, combined with per-adapter defaults);
4. a built-in default per adapter (PostgreSQL at `localhost:5432`, MySQL at
   `127.0.0.1:3306`, SQLite in `:memory:`).

The SQLite suite always runs in memory.

`config/application.json` uses the per-environment named-connection shape that
`ORM::ActiveRecord` reads:

```json
{
  "test": {
    "parallel": 4,
    "primary": { "adapter": "sqlite", "name": "db/test.sqlite3" }
  },
  "development": {
    "primary": { "adapter": "sqlite", "name": "db/development.sqlite3" }
  }
}
```

The `test` environment's `parallel` key sets how many behave worker slots the
DB-backed specs run across, and therefore how many per-worker databases get
provisioned. Copy one of the `config/application.json-*-example` files to
`config/application.json` to start.

## Per-test factory-registry reset

The factory registry is process-global mutable state. To prevent tests
leaking definitions into each other, reset it before each example.

In a behave spec:

```perl6
use BDD::Behave;
use ORM::Factory;

describe 'something', {
  before-each {
    ORM::Factory.reload;
  }

  it 'starts from an empty registry', {
    # …
  }
}
```

In a prove6 test, call `ORM::Factory.reload` at the top of each test block:

```perl6
use Test;
use ORM::Factory;

{
  ORM::Factory.reload;
  define { … };
  # assertions
}

{
  ORM::Factory.reload;
  define { … };
  # assertions
}
```

`behave` runs each spec file in its own process, so cross-file leakage isn't
possible by construction; only within-file isolation requires the manual
`reload`. `prove6` runs every `t/` file in a single harness process, so the
same `reload` discipline applies there.

## Migration runner

`bin/factory` drives
[`ORM::ActiveRecord`](https://github.com/gdonald/ORM-ActiveRecord)'s schema
tooling over `db/migrate/` to set up the test schema. It is a no-op (exit 0)
when there are no migration files, so the script is safe to invoke
unconditionally from `test.raku`.

```shell
$ raku -Ilib bin/factory            # migrate the base database
$ raku -Ilib bin/factory createdb   # create the database(s), no migrate
$ raku -Ilib bin/factory check      # report whether they exist and are migrated
```

The DB-backed specs run under behave with `--parallel=N`, where `N` is the
`test` environment's `parallel` count. behave suffixes each worker slot's
database (`factory_test_0`, `factory_test_1`, …), so `test.raku` provisions
those per-worker databases by passing `--parallel` to `createdb`, `migrate`,
and `check`. The `t/` (prove6) tests run against the base, unsuffixed database.

When `db/migrate/` is non-empty, the runner requires `ORM::ActiveRecord` to
be installed (it is a `test-depends` of `ORM::Factory`).
