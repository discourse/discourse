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

### Partitioning large steps

Most steps run in a single worker. A handful are large enough that it's worth
splitting them across CPU cores, so the framework can run one worker per chunk of
the source. A step opts in from its `source` block:

```ruby
source do
  reads_table "topic_users", where: "user_id > 0"
  partition_by :topic_id
end
```

`reads_table` is the part that reads a whole table: it defines `items`
(`SELECT * FROM topic_users WHERE …`) and `max_progress` (the row count), filtered
by `where`. It works on its own, without partitioning — a plain table-copy step
declares just `reads_table` and writes neither method. `partition_by` adds the
split: it takes the key (normally a single indexed column, so each chunk is an
index range scan; pass an array for a composite key) and reuses the table and
filter from `reads_table`, so it only needs the column. When both are present the
generated queries add the chunk to their `WHERE` automatically.

Override `items` when you need specific columns, a join, or a particular order —
and then add `partition_slice` to its `WHERE` yourself:

```ruby
def items
  @source_db.query("SELECT id, name FROM topic_users WHERE #{partition_slice} AND name IS NOT NULL")
end
```

The framework does the rest. Before forking, it asks the adapter for the chunk
boundaries — evenly sized chunks over a numeric key, or a sorted-key scan for a
text/UUID/composite key. It then forks one worker per chunk; each worker reads
its `[lower, upper)` slice (that's what `partition_slice` expands to), writes its
own SQLite shard, and the shards are merged back into the run database.

Two things to get right:

- **In a custom query, add `partition_slice` to the `WHERE`.** Miss it and each
  worker reads the whole source instead of its slice — duplicated work and wrong
  counts.
- **Only partition order-independent steps.** Workers run concurrently and their
  output is merged, so there is no global order across the step. A running total
  or a sequence number across all rows can't be partitioned. Deduplication can,
  but do it in the source query (`DISTINCT ON`, a window function, a view) and
  partition on the dedup key, rather than keeping state in `process`.

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

### Standalone install (e.g. a converter container)

A checkout of `Gemfile`, `Gemfile.lock` and `migrations/` is enough to run the converter
without the rest of the application. `BUNDLE_ONLY` restricts the install to the
migrations group and its dependencies, pinned by the root lockfile:

```bash
BUNDLE_WITH=migrations BUNDLE_ONLY=migrations bundle install
BUNDLE_WITH=migrations BUNDLE_ONLY=migrations migrations/bin/disco convert ...
```

`disco` picks up `BUNDLE_ONLY` at boot. Commands that need a booted Rails environment
(`disco check`, `disco import`) don't work in such an install.

The markdown engine additionally needs parts of the frontend to build its parser bundle
(a warm cache under `tmp/migrations/` needs neither node nor pnpm, so the build can also
happen once at image build time). A sparse checkout covers that and stays updatable with
a plain `git pull`, which only downloads blobs inside the sparse cone:

```bash
git clone --filter=blob:none --no-checkout https://github.com/discourse/discourse.git
cd discourse
git sparse-checkout set migrations lib config app/assets/stylesheets patches
git checkout main
# pnpm needs every workspace package from pnpm-workspace.yaml (an explicit list, not globs)
git sparse-checkout add $(ruby -ryaml -e 'puts YAML.load_file("pnpm-workspace.yaml")["packages"]')

BUNDLE_WITH=migrations BUNDLE_ONLY=migrations bundle install
pnpm install --frozen-lockfile
```

`lib`, `config` and `app/assets/stylesheets` are inputs of the parser bundle build. When
a new workspace package appears upstream, `pnpm install` fails naming the missing
directory; add it with `git sparse-checkout add`.

### Running tests

All specs resolve gems through the root `Gemfile` and its lockfile — the same versions as
`disco` and CI. There are no per-gem Gemfiles. Run a suite from the gem directory through
the wrapper (it fills in `BUNDLE_GEMFILE` and `BUNDLE_WITH` for fresh checkouts):

```bash
cd migrations/core       && ../bin/rspec
cd migrations/tooling    && ../bin/rspec
cd migrations/converters && ../bin/rspec
cd migrations/importer   && ../bin/rspec
```

Plain `bundle exec rspec` from a gem directory works too once the migrations group is
installed. Specs that need a booted Rails environment are tagged `:rails`; they are
excluded by default and need `MIGRATIONS_RAILS=1`:

```bash
cd migrations/<gem> && MIGRATIONS_RAILS=1 ../bin/rspec --tag rails
```

### Linting

```bash
bin/lint path/to/file
bin/lint --fix path/to/file
```

Uses both rubocop and syntax_tree. Always lint changed files.
