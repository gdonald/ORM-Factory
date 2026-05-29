#!/usr/bin/env raku

use v6.d;
BEGIN { chdir $*PROGRAM.parent }
use lib 'lib';
use lib 'specs/lib';
use JSON::Tiny;
use DBIish;
use Factory::Test::Db;

$*OUT.out-buffer = False;

%*ENV<AUTHOR_TESTING> = 1;

unless %*ENV<DBIISH_MYSQL_LIB> {
  my @candidates = $*KERNEL.name eq 'darwin'
  ?? <
  /opt/homebrew/opt/mysql-client/lib/libmysqlclient.dylib
  /usr/local/opt/mysql-client/lib/libmysqlclient.dylib
  /opt/homebrew/lib/libmysqlclient.dylib
  /usr/local/lib/libmysqlclient.dylib
  >
  !! <
  /usr/lib/x86_64-linux-gnu/libmysqlclient.so
  /usr/lib64/libmysqlclient.so
  >;
  with @candidates.first(*.IO.e) -> $p {
    %*ENV<DBIISH_MYSQL_LIB> = $p;
  }
}

sub format-ts(--> Str) {
  my $d = DateTime.now;
  sprintf '%04d-%02d-%02d %02d:%02d:%02d', $d.year, $d.month, $d.day, $d.hour, $d.minute, $d.second.Int;
}

sub try-connect(Str:D $kind, *%args --> Capture) {
  my $err;
  my $h = try {
    CATCH { default { $err = .message } }
    DBIish.connect($kind, |%args);
  };
  $h.dispose if $h.defined;
  \($h.defined, $err // '');
}

sub classify(Str:D $err --> Str) {
  return 'driver' if $err ~~ /:i 'could not find' | 'cannot load' | 'no such module' | 'cannot locate' | 'unable to find' | 'load library'/;
  return 'driver' if $err ~~ /:i 'libsqlite' | 'libpq' | 'libmysqlclient'/ && $err ~~ /:i 'cannot' | 'failed' | 'not found'/;
  return 'refused' if $err ~~ /:i 'connection refused' | 'could not connect' | 'cannot connect' | 'no route' | 'host is down' | 'timed out'/;
  return 'auth' if $err ~~ /:i 'authentication' | 'access denied' | 'password authentication failed' | 'role .* does not exist'/;
  return 'database' if $err ~~ /:i 'database .* does not exist' | 'unknown database'/;
  'other';
}

my %ADAPTERS =
postgres => {
  dbiish          => 'Pg',
  env             => 'FACTORY_PG_URL',
  default-url     => 'postgres://postgres@localhost:5432/factory_test',
  defaults        => { host => 'localhost', port => 5432, user => 'postgres', name => 'factory_test' },
  connect-args    => -> %c {
    host     => %c<host>,
    port     => %c<port>.Int,
    user     => %c<user>,
    password => %c<password> // '',
    database => %c<name>,
  },
  messages => {
    driver => -> %, $err {
      qq:to/MSG/.chomp;
        PostgreSQL driver not loadable.
          error: $err
          fix (Debian/Ubuntu):
            sudo apt-get install -y libpq-dev
            zef install --/test --force-install DBIish

          fix (macOS / Homebrew):
            brew install libpq
            export PATH="\$(brew --prefix libpq)/bin:\$PATH"
            export PKG_CONFIG_PATH="\$(brew --prefix libpq)/lib/pkgconfig:\$PKG_CONFIG_PATH"
            zef install --/test --force-install DBIish
        MSG
    },
    refused => -> %c, $err {
      my ($host, $port, $user, $name) = %c<host port user name>;
      qq:to/MSG/.chomp;
        PostgreSQL not reachable at $host:$port.
          error: $err
          fix:   docker run -d --name factory-pg -p 5432:5432 \\
                    -e POSTGRES_USER=$user -e POSTGRES_PASSWORD=postgres \\
                    -e POSTGRES_DB=$name postgres:17
                 or set FACTORY_PG_URL='postgres://USER:PASS\@HOST:PORT/DB'
                 or edit config/application.json (db.adapter=pg)
        MSG
    },
    auth => -> %c, $err {
      my ($host, $port, $user, $name) = %c<host port user name>;
      qq:to/MSG/.chomp;
        PostgreSQL auth failed for user '$user' at $host:$port.
          error: $err
          fix:   set FACTORY_PG_URL='postgres://USER:PASS\@$host:$port/$name'
                 or update user/password in config/application.json
        MSG
    },
    database => -> %c, $err {
      my ($host, $port, $user, $name) = %c<host port user name>;
      qq:to/MSG/.chomp;
        PostgreSQL database '$name' does not exist on $host:$port.
          error: $err
          fix:   createdb -h $host -p $port -U $user $name
                 or set FACTORY_PG_URL to point at an existing db
        MSG
    },
    default => -> %, $err {
      qq:to/MSG/.chomp;
        PostgreSQL probe failed.
          error: $err
          fix:   set FACTORY_PG_URL='postgres://USER:PASS\@HOST:PORT/DB'
                 or edit config/application.json
        MSG
    },
  },
},
mysql => {
  dbiish       => 'mysql',
  env          => 'FACTORY_MYSQL_URL',
  default-url  => 'mysql://root@127.0.0.1:3306/factory_test',
  defaults     => { host => '127.0.0.1', port => 3306, user => 'root', name => 'factory_test' },
  connect-args => -> %c {
    host     => %c<host>,
    port     => %c<port>.Int,
    user     => %c<user>,
    password => %c<password> // '',
    database => %c<name>,
  },
  messages => {
    driver => -> %, $err {
      qq:to/MSG/.chomp;
        MySQL driver not loadable.
          error: $err
          cause: DBDish::mysql searches libmysqlclient versions 16..21 only,
                 but recent installs ship version 24+. It does NOT consult
                 pkg-config or mysql_config — only the DBIISH_MYSQL_LIB env
                 var (or the standard dynamic-loader search path).

          fix (macOS / Homebrew):
            brew install mysql-client
            export DBIISH_MYSQL_LIB=\$(brew --prefix mysql-client)/lib/libmysqlclient.dylib

          fix (Debian/Ubuntu):
            sudo apt-get install -y libmysqlclient21
            export DBIISH_MYSQL_LIB=/usr/lib/x86_64-linux-gnu/libmysqlclient.so

          Then re-run ./test.raku — it auto-detects DBIISH_MYSQL_LIB on next
          invocation if mysql-client is in a standard Homebrew or apt path.
        MSG
    },
    refused => -> %c, $err {
      my ($host, $port, $name) = %c<host port name>;
      qq:to/MSG/.chomp;
        MySQL not reachable at $host:$port.
          error: $err
          fix:   docker run -d --name factory-mysql -p 3306:3306 \\
                    -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=$name mysql:8.4
                 or set FACTORY_MYSQL_URL='mysql://USER:PASS\@HOST:PORT/DB'
        MSG
    },
    auth => -> %c, $err {
      my ($host, $port, $user, $name) = %c<host port user name>;
      qq:to/MSG/.chomp;
        MySQL auth failed for user '$user' at $host:$port.
          error: $err
          fix:   set FACTORY_MYSQL_URL='mysql://USER:PASS\@$host:$port/$name'
        MSG
    },
    database => -> %c, $err {
      my ($host, $port, $user, $name) = %c<host port user name>;
      qq:to/MSG/.chomp;
        MySQL database '$name' does not exist on $host:$port.
          error: $err
          fix:   mysql -h $host -P $port -u $user -p -e 'CREATE DATABASE $name'
                 or set FACTORY_MYSQL_URL to point at an existing db
        MSG
    },
    default => -> %, $err {
      qq:to/MSG/.chomp;
        MySQL probe failed.
          error: $err
          fix:   set FACTORY_MYSQL_URL='mysql://USER:PASS\@HOST:PORT/DB'
        MSG
    },
  },
},
sqlite => {
  dbiish       => 'SQLite',
  env          => 'FACTORY_SQLITE_URL',
  default-url  => 'sqlite:db/test.sqlite3',
  defaults     => {},
  connect-args => -> % { database => ':memory:' },
  messages => {
    driver => -> %, $err {
      qq:to/MSG/.chomp;
        SQLite driver not loadable.
          error: $err
          fix (Debian/Ubuntu):
            sudo apt-get install -y libsqlite3-dev
            zef install --/test --force-install DBIish

          fix (macOS): libsqlite3 is preinstalled; just rebuild:
            zef install --/test --force-install DBIish
        MSG
    },
    default => -> %, $err {
      qq:to/MSG/.chomp;
        SQLite probe failed.
          error: $err
          fix:   ensure libsqlite3 is on the system; reinstall with
                 `zef install --/test --force-install DBIish`
        MSG
    },
  },
};

# config/application.json names one adapter and its connection. Every adapter
# shares the database NAME; a non-matching adapter keeps its own host/port/user
# defaults but still targets the configured name, so the file is the single
# source of truth for the test database name across postgres, mysql, and sqlite.
sub url-from-config(Str:D $adapter --> Str) {
  return Str if $adapter eq 'sqlite';   # the suite always runs SQLite in :memory:
  return Str unless 'config/application.json'.IO.e;

  my $json = try { from-json('config/application.json'.IO.slurp) };
  return Str without $json;

  my %db   = $json<db> // %();
  my $name = %db<name>;
  return Str without $name;

  my %defaults = %ADAPTERS{$adapter}<defaults>;

  my $cfg = (%db<adapter> // 'pg').lc;
  $cfg = 'postgres' if $cfg eq 'pg' || $cfg eq 'postgresql';
  $cfg = 'mysql'    if $cfg eq 'mysql2' || $cfg eq 'mariadb';

  my ($host, $port, $user, $pass);
  if $cfg eq $adapter {
    $host = %db<host>     // %defaults<host>;
    $port = %db<port>     // %defaults<port>;
    $user = %db<user>     // %defaults<user>;
    $pass = %db<password> // '';
  } else {
    $host = %defaults<host>;
    $port = %defaults<port>;
    $user = %defaults<user>;
    $pass = '';
  }

  my $scheme = $adapter eq 'postgres' ?? 'postgres' !! 'mysql';
  my $auth   = $user ?? ($user ~ ($pass ?? ":$pass" !! '') ~ '@') !! '';
  my $hp     = $port ?? "$host:$port" !! $host;
  my $q      = ($adapter eq 'postgres' && %db<schema>) ?? "?schema={%db<schema>}" !! '';

  "$scheme://$auth$hp/$name$q";
}

sub skip-message(Str:D $name, %c, Str:D $err --> Str) {
  my %a = %ADAPTERS{$name};
  my $cls = classify($err);
  my $tpl = %a<messages>{$cls} // %a<messages><default>;
  $tpl.(%c, $err);
}

sub probe(Str:D $name, Str:D $url --> Capture) {
  return \(False, "unknown adapter $name", "unknown adapter $name") unless %ADAPTERS{$name}:exists;
  my %a = %ADAPTERS{$name};
  my %c = parse-database-url($url);
  for %a<defaults>.kv -> $k, $v { %c{$k} //= $v }
  my %args = %a<connect-args>.(%c);
  my ($ok, $err) = try-connect(%a<dbiish>, |%args).list;
  \($ok, $err, $ok ?? '' !! skip-message($name, %c, $err));
}

# behave runs every spec file in its own process (one EVAL'd compunit per
# invocation), giving each spec a clean per-file isolation model.
sub run-behave(@specs --> Int) {
  my $fail = 0;
  my $cwd  = $*CWD.absolute;
  for @specs.map(*.absolute).sort -> $f {
    my $rel = $f.starts-with($cwd ~ '/') ?? $f.substr($cwd.chars + 1) !! $f;
    say $rel;
    my $proc = run 'behave', $f;
    $fail = $proc.exitcode if $proc.exitcode != 0;
  }
  $fail;
}

# prove6 runs the whole t/ set in a single harness invocation.
sub run-prove6(@tests --> Int) {
  return 0 unless @tests;
  my $proc = run 'prove6', '-Ilib', |@tests.map(*.absolute).sort;
  $proc.exitcode;
}

# A pass runs the t/ tests (prove6) and specs/ specs (behave) for one bucket.
sub run-pass(:@tests, :@specs --> Int) {
  my $t = run-prove6(@tests);
  my $s = run-behave(@specs);
  ($t != 0 || $s != 0) ?? 1 !! 0;
}

sub run-db-pass(Str:D :$name, Str:D :$url, :@tests, :@specs --> Int) {
  say '';
  say "==> [{format-ts()}] adapter=$name";
  %*ENV<DATABASE_URL>     = $url;
  %*ENV<DISABLE-SQL-LOG> //= 'True';
  %*ENV<ORM_LOG_FILE>    //= ('log'.IO.d ?? 'log/error.log' !! '/dev/null');

  # Persistence tests/specs need the test schema in place. Migrate only once
  # bin/factory exists.
  if 'bin/factory'.IO.e {
    my $migrate = run :env(%*ENV, DISABLE-SQL-LOG => 'True'),
    'raku', '-Ilib', 'bin/factory';
    return $migrate.exitcode unless $migrate.exitcode == 0;
  }

  my $fail = run-pass(:@tests, :@specs);

  # `create`-strategy tests/specs leave rows behind, and one that exercises
  # migrations can alter the schema. Re-run migrations so the next test.raku
  # run starts from the canonical schema.
  if 'bin/factory'.IO.e {
    run :env(%*ENV, DISABLE-SQL-LOG => 'True'),
    'raku', '-Ilib', 'bin/factory';
  }

  $fail;
}

sub find-spec-files(IO::Path $dir) {
  my @out;
  for $dir.dir -> $entry {
    next if $entry.basename.starts-with('.');
    if $entry.d {
      @out.append: find-spec-files($entry);
    } elsif $entry.basename ~~ /spec '.' raku $/ {
      @out.push: $entry;
    }
  }
  @out;
}

sub find-test-files(IO::Path $dir) {
  my @out;
  for $dir.dir -> $entry {
    next if $entry.basename.starts-with('.');
    if $entry.d {
      @out.append: find-test-files($entry);
    } elsif $entry.extension eq 'rakutest' || $entry.extension eq 't' {
      @out.push: $entry;
    }
  }
  @out;
}

sub parse-args(--> Hash) {
  my %alias = pg => 'postgres', postgres => 'postgres', postgresql => 'postgres',
  mysql => 'mysql',
  sqlite => 'sqlite', sqlite3 => 'sqlite';
  my @args = @*ARGS;
  if @args.grep({ $_ eq '-h' || $_ eq '--help' }) {
    say q:to/USAGE/;
    Usage: ./test.raku [--adapter=NAME[,NAME...]] [--unit-only|--no-unit]
      NAME: pg|postgres|mysql|sqlite (default: all configured)
      --unit-only  run only the DB-agnostic unit pass
      --no-unit    skip the unit pass; run only DB-backed passes
    USAGE
    exit 0;
  }
  my @picked;
  my $unit-only = False;
  my $no-unit   = False;
  my $i = 0;
  while $i < @args.elems {
    my $a = @args[$i];
    if $a ~~ /^ '--adapter=' (.+) $/ {
      @picked.append: ~$0;
    } elsif $a eq '--adapter' {
      die "--adapter requires a value" unless $i + 1 < @args.elems;
      @picked.append: @args[++$i];
    } elsif $a eq '--unit-only' {
      $unit-only = True;
    } elsif $a eq '--no-unit' {
      $no-unit = True;
    } else {
      die "unknown arg: $a (use --adapter=pg|mysql|sqlite, --unit-only, or --no-unit)";
    }
    $i++;
  }
  die "--unit-only and --no-unit are mutually exclusive" if $unit-only && $no-unit;
  my @wanted = @picked.map(*.split(',', :skip-empty)).flat.map({
      %alias{.lc} // die "unknown adapter: $_ (use pg|mysql|sqlite)"
  }).list;
  { :@wanted, :$unit-only, :$no-unit };
}

my %opts     = parse-args();
my @wanted   = %opts<wanted>.list;
my $unit-only = %opts<unit-only>;
my $no-unit   = %opts<no-unit>;

# t/ tests (prove6) and specs/ specs (behave) mirror each other. In both trees,
# files under a top-level db/ are DB-backed (run once per reachable adapter,
# with migration); everything else is DB-agnostic and runs once in the unit pass.
my $specs-root = 'specs'.IO;
my @all-specs  = $specs-root.d ?? find-spec-files($specs-root) !! ();
my @db-specs   = @all-specs.grep({  .relative($specs-root).starts-with('db/') }).list;
my @unit-specs = @all-specs.grep({ !.relative($specs-root).starts-with('db/') }).list;

my $tests-root = 't'.IO;
my @all-tests  = $tests-root.d ?? find-test-files($tests-root) !! ();
my @db-tests   = @all-tests.grep({  .relative($tests-root).starts-with('db/') }).list;
my @unit-tests = @all-tests.grep({ !.relative($tests-root).starts-with('db/') }).list;

my @runs;
my Bool $skip-probe = False;

# Adapters are needed only for DB-backed tests/specs; skip all probing when
# there are none, so the unit pass never depends on a database being present.
if (@db-specs || @db-tests) && !$unit-only {
  if my $external = %*ENV<DATABASE_URL> {
    my $kind = parse-database-url($external)<adapter>;
    my $name = $kind eq 'pg' ?? 'postgres' !! $kind;
    @runs.push: { :$name, :url($external) };
    $skip-probe = True;
  } else {
    for <postgres mysql sqlite> -> $name {
      my %a = %ADAPTERS{$name};
      my $url = %*ENV{%a<env>} // url-from-config($name) // %a<default-url>;
      @runs.push: { :$name, :$url };
    }
  }

  if @wanted {
    my %want = @wanted.map: * => True;
    @runs = @runs.grep({ %want{ .<name> } }).list;
    die "no adapters matched --adapter filter ({@wanted.join(',')})" unless @runs;
  }
}

my @skipped;
my $any-fail = False;
my %durations;
my $total-start = now;

END {
  if %durations {
    say '';
    say '==> Runtimes';
    printf "  %-9s %7.2fs\n", 'unit', %durations<unit> if %durations<unit>:exists;
    for @runs -> %r {
      next unless %durations{%r<name>}:exists;
      printf "  %-9s %7.2fs\n", %r<name>, %durations{%r<name>};
    }
    printf "  %-9s %7.2fs\n", 'total', (now - $total-start).Num;
  }
  if @skipped {
    say '';
    say '==> Skipped';
    for @skipped -> $s {
      say "  - $s<name>";
      say $s<msg>.indent(6);
    }
  }
}

# Unit pass: DB-agnostic t/ tests + specs/ specs, run once.
if (@unit-tests || @unit-specs) && !$no-unit {
  say '';
  say "==> [{format-ts()}] unit";
  my $start = now;
  my $rc = run-pass(:tests(@unit-tests), :specs(@unit-specs));
  %durations<unit> = (now - $start).Num;
  $any-fail = True if $rc != 0;
}

# Adapter passes: DB-backed t/ tests + specs/ specs against each reachable adapter.
for @runs -> %r {
  my $name = %r<name>;
  my $url  = %r<url>;

  unless $skip-probe {
    my ($ok, $err, $msg) = probe($name, $url).list;
    unless $ok {
      say '';
      say "==> [{format-ts()}] SKIP $name";
      say $msg.indent(2);
      @skipped.push: { :$name, :$msg };
      next;
    }
  }

  my $start = now;
  my $rc = run-db-pass(:$name, :$url, :tests(@db-tests), :specs(@db-specs));
  %durations{$name} = (now - $start).Num;
  $any-fail = True if $rc != 0;
}

exit $any-fail ?? 1 !! 0;
