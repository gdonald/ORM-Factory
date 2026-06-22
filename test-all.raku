#!/usr/bin/env raku

use v6.d;
BEGIN { chdir $*PROGRAM.parent }

my @examples = dir('config').grep({ .basename ~~ /'application.json-' .* '-example' $/ }).sort;

my $config = 'config/application.json'.IO;
my $backup = 'config/application.json.test-all-backup'.IO;

sub restore-config {
  return unless $backup.e;
  $backup.copy($config);
  $backup.unlink;
}

$config.copy($backup) if $config.e;

# Restore the original config if a run throws mid-loop; the explicit call below
# covers the normal path, since `exit` does not run LEAVE phasers.
LEAVE restore-config;

my $failures = 0;

for @examples -> $example {
  say '';
  say '=' x 72;
  say "Running test.raku with {$example.basename}";
  say '=' x 72;

  $example.copy($config);

  my $proc = run './test.raku', @*ARGS;
  $failures++ unless $proc.exitcode == 0;
}

restore-config;
exit $failures ?? 1 !! 0;
