use v6.d;
use ORM::Factory ();

unit module ORM::Factory::DSL;

# Opt-in bare-name DSL: an ergonomic alternative to the canonical leading-dot
# form, with no slang and no macro (just exported subs over a dynamic builder).
# Use this module INSTEAD of ORM::Factory; it re-exports the build/query helpers
# so it is self-contained. The dotted form (`ORM::Factory.define { .factory: ...
# }`) is unchanged and remains the default API.
#
#   use ORM::Factory::DSL;
#
#   define {
#     factory 'user', {
#       attr 'fname', 'Greg';                       # explicit attribute setter
#       attrs(:lname<Donald>, :email({ ... }));     # colon-pair list
#       variant 'admin', { attr 'role', 'admin' };
#     };
#   };
#
# Every keyword dispatches to the active builder found in $*FACTORY-DSL. The
# builders run their blocks deferred (stored at define-time, invoked during
# registration with the builder as the topic), so each wrapper rebinds
# $*FACTORY-DSL to the builder it is handed before running the user's block.

my sub topic-binder(&user) {
  -> $builder { my $*FACTORY-DSL := $builder; user() }
}

# --- definition entry points ---

our sub define(&user) is export { ORM::Factory.define(topic-binder(&user)) }
our sub modify(&user) is export { ORM::Factory.modify(topic-binder(&user)) }

# --- block-bearing keywords (retarget $*FACTORY-DSL for their body) ---

our sub factory(Str:D $name, &user, *%opts) is export {
  $*FACTORY-DSL.factory($name, topic-binder(&user), |%opts);
}

our sub variant(Str:D $name, &user) is export {
  $*FACTORY-DSL.variant($name, topic-binder(&user));
}

our sub transient(&user) is export {
  $*FACTORY-DSL.transient(topic-binder(&user));
}

# --- leaf keywords (dispatch to the active builder) ---

our sub sequence(Str:D $name, &block?, :$start = 1, Iterator :$iterator) is export {
  $*FACTORY-DSL.sequence($name, &block, :$start, :$iterator);
}

our sub association(Str:D $name, *@pos, *%opts) is export {
  $*FACTORY-DSL.association($name, |@pos, |%opts);
}

our sub before(Str:D $event, &block) is export { $*FACTORY-DSL.before($event, &block) }
our sub after(Str:D $event, &block)  is export { $*FACTORY-DSL.after($event, &block) }
our sub callback(Str:D $event, &block) is export { $*FACTORY-DSL.callback($event, &block) }

our sub to-create(&block)        is export { $*FACTORY-DSL.to-create(&block) }
our sub initialize-with(&block)  is export { $*FACTORY-DSL.initialize-with(&block) }
our sub skip-create()            is export { $*FACTORY-DSL.skip-create }

our sub variants-for-enum(Str:D $attr-name, @values) is export {
  $*FACTORY-DSL.variants-for-enum($attr-name, @values);
}

# --- attributes ---

# Explicit setter. Order-preserving, and the only form for a dependent chain
# that must read in a fixed order.
our sub attr(Str:D $name, |c) is export {
  $*FACTORY-DSL.add-attribute($name, |c);
}

# Colon-pair / adverb list. A Callable value becomes a dynamic attribute. Note:
# these arrive as named arguments, so declaration order is NOT preserved across
# the list; use sequential `attr` calls when order matters.
our sub attrs(*%pairs) is export {
  for %pairs.kv -> $name, $value {
    $*FACTORY-DSL.add-attribute($name, $value);
  }
}

# --- build / query helpers (re-exported so this module stands alone) ---

our sub build(Str:D $name, |c)               is export { ORM::Factory.build($name, |c) }
our sub create(Str:D $name, |c)              is export { ORM::Factory.create($name, |c) }
our sub build-stubbed(Str:D $name, |c)       is export { ORM::Factory.build-stubbed($name, |c) }
our sub attributes-for(Str:D $name, |c)      is export { ORM::Factory.attributes-for($name, |c) }
our sub build-list(Str:D $name, Int:D $n, |c)          is export { ORM::Factory.build-list($name, $n, |c) }
our sub create-list(Str:D $name, Int:D $n, |c)         is export { ORM::Factory.create-list($name, $n, |c) }
our sub build-stubbed-list(Str:D $name, Int:D $n, |c)  is export { ORM::Factory.build-stubbed-list($name, $n, |c) }
our sub attributes-for-list(Str:D $name, Int:D $n, |c) is export { ORM::Factory.attributes-for-list($name, $n, |c) }
our sub build-pair(Str:D $name, |c)          is export { ORM::Factory.build-pair($name, |c) }
our sub create-pair(Str:D $name, |c)         is export { ORM::Factory.create-pair($name, |c) }
our sub generate(Str:D $name)                is export { ORM::Factory.generate($name) }
our sub generate-list(Str:D $name, Int:D $n) is export { ORM::Factory.generate-list($name, $n) }
our sub reload()                             is export { ORM::Factory.reload }
