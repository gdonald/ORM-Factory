use v6.d;
use META6;

# Shared META6.json introspection for the meta test (t/) and meta spec (specs/),
# so the derivation lives in one place.
unit module Factory::Test::Meta;

sub find-rakumod(IO::Path $dir) {
  gather for $dir.dir {
    when .d                      { .take for find-rakumod($_) }
    when .extension eq 'rakumod' { .take }
  }
}

sub meta-facts(--> Hash) is export {
  my $meta-file = 'META6.json'.IO;
  my $meta      = META6.new(file => $meta-file);

  {
    file           => $meta-file,
    meta           => $meta,
    provides       => $meta.provides.pairs.sort(*.key).List,
    provided-paths => $meta.provides.values.Set,
    lib-rakumod    => find-rakumod('lib'.IO).map(*.relative).sort.List,
  }
}
