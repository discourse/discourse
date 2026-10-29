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

### Database ownership and fork safety

All database handles in migrations tooling must be opened through
`Database::ManagedConnection.open(driver)`. The converter and importer share
`Database::Drivers::Postgres`; SQLite uses `Database::Drivers::Sqlite` through
`Database::Connection`. `Connection.open_database` also returns a managed wrapper,
not a native SQLite handle. Close connections explicitly or use a block-scoped factory.

A driver implements `open`, `configure(handle)`, and `close(handle)`. Its constructor
must clean up native allocations if it raises before returning a handle. The manager
owns registration, configuration failure cleanup, operation leases, and removal after
successful close. A failed close retains the registration so a live handle cannot become
invisible to the fork coordinator. Adapter code uses `with { |handle| ... }` internally;
do not retain or expose the native handle outside that operation.

Drivers without an explicit policy prohibit forks while their connections are open.
There is no fallback worker backend. To support forks, implement and test one of:

| Policy | Driver contract | Current use |
| --- | --- | --- |
| `:forbid` (default) | Close the connection before starting workers. | General SQLite connections, including importer databases and schema tooling. |
| `:discard` | `discard(handle)` must neutralize inherited native cleanup without affecting the parent. | PostgreSQL; redirect its socket before libpq can send Terminate. |
| `:close_reopen` | `validate_fork!(handle)` must reject state that cannot be restored by `open` and `configure`. | Only explicitly reopenable SQLite connections, such as the converter's run database. |

SQLite connections require `reopenable: true` to opt in. Active transactions, attached
schemas, and temporary schema objects prevent a fork. The caller must finish its work
explicitly; forking does not commit transactions. This mode is for run connections whose
session configuration is defined by the driver, not arbitrary user-managed SQLite
sessions. Worker shards are opened in their worker and do not opt in. Do not use or call
SQLite's close API on an inherited live connection; see
[SQLite's fork guidance](https://www.sqlite.org/howtocorrupt.html#_carrying_an_open_database_connection_across_a_fork_).

`ForkManager` remains the sole worker-fork entry point. `Database::Lifecycle` owns the
registry and barrier. Construction and destruction hold shared leases; SQLite operations
also hold them. The entire prepare/fork-batch/restore interval holds exclusive access.
Concurrent PostgreSQL queries can continue while workers fork. Reentrant shared leases
follow threads so SQLite streaming fibers can nest operations, while PostgreSQL operation
leases prevent another fiber from reusing an active protocol stream. Forking inside an
active database operation or opening a connection inside a fork batch raises an error.

Ordinary forks and batches use the same protocol. All policies are validated before
connections are closed. If preparation or forking fails, every successfully suspended
connection is restored. Restoration attempts continue even if one fails; failed resources
remain unavailable. Partially started batches terminate and reap their unreaped workers.
If child-side discard or another child initialization hook fails, the child exits immediately
without running worker code or inherited exit handlers. PID checks also reject accidental
use of inherited connections and streams.

`Database::PostgresStream` is single-pass. `each` releases its lease and drains pending
results on exhaustion, early block exit, or an exception. When manually using `next`,
call `close` if stopping early. Closing a connection with an active operation raises
`BusyError`; an abandoned stream must not silently release protection while its query is
still in progress. The source adapter and importer both use this stream implementation.

#### Testing and enforcing adapter contracts

New drivers must pass the shared `a managed database driver` examples and add tests for
their native discard or restoration strategy. The lifecycle tests force construction,
close, and fork interleavings with queues, and exercise failure recovery for ordinary
forks and batches. Every fork test must reap its child and check its status or transport
its failure to the parent; assertions raised only in a child do not fail the parent runner.

The core boundary spec parses production Ruby files to restrict known native connection
constructors to their driver files and raw forks to `ForkManager`. Extend its constructor
list when adding a database library. This catches accidental bypasses; arbitrary native
libraries cannot be made fork-safe by inspecting their Ruby wrappers alone. Database
drivers must not implement their own independent fork hooks.

Real PostgreSQL lifecycle tests run without Rails against a disposable session in an
existing database (only temporary objects may be created):

```bash
cd migrations/core
PGHOST=/var/run/postgresql MIGRATIONS_POSTGRES_DB=discourse_development ../bin/rspec --tag postgres
```

The migration CI job enables these tests against the `postgres` database, alongside the
real SQLite tests. Verify that removing protection makes regression tests fail. Repeated
full conversions supplement these deterministic tests; they cannot prove all possible
interleavings safe.

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
