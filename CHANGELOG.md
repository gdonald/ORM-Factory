# Changelog

All notable changes to `ORM::Factory` are documented here.

## 0.9.0

### Added

- Bare-name DSL (`ORM::Factory::DSL`), an opt-in module that defines factories without the leading-dot method-call syntax. Plain Raku exported subs over a dynamic builder, re-exporting the build and query helpers so it is self-contained.
- Migration support for setting up and tearing down database schema in specs.
- Configuration and linting.
- Build and save options.
- Callbacks.
- Variants.
- Associations.
- Factory inheritance.
- Build strategies.
- `factory` binary.

### Changed

- Use `ORM::ActiveRecord` enums.
- Updated to match the latest `behave --parallel`.
- Shorter factory definition syntax.

### Fixed

- Doc warnings.
- CI truncation between specs.
- `.throw` handling.
