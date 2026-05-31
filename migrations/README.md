# Migrations Tooling

The tooling is split into four path-referenced gems under `migrations/`:
`core`, `tooling`, `converters`, and `importer`.

## Command line interface

```bash
./core/bin/disco help
```

## Converters

Public converters are stored in `converters/lib/migrations/converters/`.
If you need to run a private converter, put its code into a subdirectory of
`private/converters/` (or point `MIGRATIONS_PRIVATE_CONVERTERS_PATH` at it).

## Development

### Installing gems

```bash
bundle config set --local with migrations
bundle install
```

### Updating gems

```bash
bundle update --group migrations
```

### Running tests

Each gem has an isolated, no-Rails suite:

```bash
cd migrations/core && bundle exec rspec
```

Specs that need a booted Rails environment are tagged `:rails` and run from the host app's
bundle:

```bash
cd migrations/<gem> && BUNDLE_GEMFILE=../../Gemfile MIGRATIONS_RAILS=1 bundle exec rspec --tag rails
```
