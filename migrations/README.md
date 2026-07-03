# Migrations Tooling

The `migrations/` directory is split into four path-referenced gems:

- `core/` — `Migrations::*`: CLI framework, UI, SQLite schemas, DB infrastructure,
  IntermediateDB models, and the conversion framework (`Migrations::Conversion::*`).
- `tooling/` — `Migrations::Tooling::*`: the schema DSL, `disco schema` commands, benchmarks.
- `converters/` — `Migrations::Converters::*`: public converter implementations + source adapters.
- `importer/` — `Migrations::Importer::*`: the row importer and the uploads importer.

All four are wired into the root `Gemfile` via `path:` in the optional `:migrations` group.

## Command line interface

The single binary is `migrations/bin/disco` (commands register dynamically via
`Migrations::CLI::Registry`). Run it without arguments — or with `--help` — for the
authoritative, always-current list of commands:

```bash
migrations/bin/disco --help
```

Rails is booted lazily: only commands that declare `requires_rails!` (import, upload, schema)
load the Discourse app.

## Converters

Public converters live in `converters/lib/migrations/converters/`. To run a private
(closed-source) converter, put its code in a subdirectory of `private/converters/`
(or point `MIGRATIONS_PRIVATE_CONVERTERS_PATH` at it).

### Source DB adapters and fork safety

Worker processes inherit the source DB connection's socket from the main process. Whether
that's dangerous depends on the client library: a destructor that only closes the file
descriptor is harmless (the parent still holds it, so the kernel sends nothing over the
wire), but a destructor that writes a protocol goodbye kills the parent's session as soon
as a worker exits — libpq sends a Terminate message, MySQL clients send `COM_QUIT`.

`Adapter::Postgres` handles this by registering a `ForkManager.after_fork_child` hook that
calls `discard!` in each worker: the inherited socket is redirected to `/dev/null`, and any
later use of the adapter in the worker raises `DiscardedError`. New adapters should follow
the same pattern. The discard mechanism itself is library-specific — mysql2 has
`automatic_close = false`, trilogy has a native `discard!`. To check whether a library
needs one at all: connect, fork an empty child that exits normally, wait for it, and query
again from the parent (see the fork-safety specs in `postgres_spec.rb`).

## Schema DSL

The schema DSL lives in `migrations/tooling/lib/migrations/tooling/schema/dsl/`. Config sources
are in `migrations/tooling/config/schema/`. Generated artifacts (SQL, models, enums) are written
into `migrations/core/`.

Key files:
- `table_builder.rb` - DSL for defining table configs
- `schema_resolver.rb` - Resolves DSL config + DB introspection into final schema
- `conventions_builder.rb` - Global column conventions (renames, type overrides)
- `generator.rb` - Generates SQL, models, and enums from resolved schema
- `validator.rb` - Validates DSL config
- `resolved_schema_validator.rb` - Validates resolved schema before generation

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

Each gem has an isolated, no-Rails suite, run from the gem directory:

```bash
cd migrations/core       && bundle exec rspec
cd migrations/tooling    && bundle exec rspec
cd migrations/converters && bundle exec rspec
cd migrations/importer   && bundle exec rspec
```

Specs that need a booted Rails environment are tagged `:rails`. They are excluded by default and
run from the host app's bundle:

```bash
cd migrations/<gem> && BUNDLE_GEMFILE=../../Gemfile MIGRATIONS_RAILS=1 bundle exec rspec --tag rails
```

### Linting

```bash
bin/lint path/to/file
bin/lint --fix path/to/file
```

Uses both rubocop and syntax_tree. Always lint changed files.

## Known issues

- **Parallel step items must be hashes (or other non-scalar JSON values).** Worker processes
  receive their items as an Oj stream over a pipe, and Oj's stream parser can only detect the
  end of a bare scalar (a number or string) once the next byte arrives — so a step whose
  `items` yields scalars stalls the worker pipeline. Wrap scalar items in a hash
  (e.g. `{ id: ... }`). This should go away if we switch the worker pipes from Oj to JSON.
