use v6.d;

# Adapter protocol that decouples the factory engine from any specific ORM.
# Build strategies target this role; concrete adapters (e.g. for
# ORM::ActiveRecord) implement it.
#
# `attributes-for` deliberately bypasses the adapter entirely: it returns a
# plain attribute hash without ever instantiating, persisting, or stubbing.
unit role ORM::Factory::Persistence;

method instantiate(Mu $class, %attrs) { ... }

method persist(Mu $instance) { ... }

method is-valid(Mu $instance --> Bool) { True }

method errors(Mu $instance) { Empty }

method primary-key(Mu $class --> Str) { 'id' }

method stub(Mu $instance) { $instance }
