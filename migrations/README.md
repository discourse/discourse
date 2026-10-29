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
invisible to the fork coordinator. Ordinary adapter operations use
`with { |handle| ... }`. PostgreSQL streams reserve the connection with `checkout` and
release it with `checkin` when drained; never expose that handle to callers.

Registration alone is insufficient: a native constructor can open a socket before
returning the handle to Ruby. A child forked in that interval cannot find the handle to
discard it, and later native cleanup can terminate the parent's session. The barrier
must cover native construction **and assignment**, configuration, and close through
unregistration. Keep the deterministic constructor-overlap test when changing this code.

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
registry and barrier. Construction and destruction hold shared leases; operations on
reopenable SQLite connections also hold them. The entire prepare/fork-batch/restore
interval holds exclusive access. Concurrent PostgreSQL queries can continue while workers
fork. PostgreSQL reserves its protocol once per stream, preventing another query or close
until consumption finishes. Opening a connection inside a fork batch raises an error.

Worker shards and importer SQLite connections prohibit forks for their entire lifetime.
They therefore need no global operation barrier. Cached inserts execute directly, with
ownership checks at transaction boundaries and statement preparation; close clears the
cache. These connections belong to one worker or importer thread, and must not be shared
for concurrent inserts and close. The converter's reopenable run database retains an
operation lease around inserts, reads, and merges. Keep that distinction explicit when
adding a new execution path: do not add locks to every row to protect against a fork that
the connection's lifetime policy already prohibits.

Ordinary forks and batches use the same protocol. All policies are validated before
connections are closed. If preparation or forking fails, every successfully suspended
connection is restored. Restoration attempts continue even if one fails; failed resources
remain unavailable. Partially started batches terminate and reap their unreaped workers.
If child-side discard or another child initialization hook fails, the child exits immediately
without running worker code or inherited exit handlers. PID checks also reject accidental
use of inherited connections and streams.

`Database::PostgresStream` is single-pass. Normal `each` iteration passes the consumer's
block directly to the native stream, without a Fiber switch or ownership check per row.
Only explicit `next` iteration creates a Fiber. `each` releases its lease and drains pending
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

#### Benchmarking database changes

Use [the database pipeline benchmark](tooling/benchmarks/database_pipeline.rb) for changes
to drivers, connection wrappers, streaming, or fork coordination. Run the **same script**
against both revisions using their respective `BUNDLE_GEMFILE`, with the same Ruby,
PostgreSQL, and storage. Alternate revision order, warm each process before measuring,
and compare repeated samples of elapsed time and CPU time. CPU includes reaped workers;
allocation counts cover only the parent. Do not run tests or other benchmarks concurrently.

```bash
BUNDLE_WITH=migrations PGHOST=/var/run/postgresql PGDATABASE=discourse_development \
  ROWS=250000 ROUNDS=7 bundle exec ruby migrations/tooling/benchmarks/database_pipeline.rb convert
```

Modes are `sqlite`, `stream_hash`, `stream_wide`, `stream_array`, `convert`,
`convert_inline`, and `import`. `convert` runs four concurrent steps, each with `ROWS`
source records, through the actual scheduler, PostgreSQL adapter, processors, worker
shards, and consolidator. `convert_inline` runs the same steps without forks. `import`
reads SQLite rows, copies them through the importer's PostgreSQL adapter in 1,000-row
batches, and writes ID mappings to SQLite between batches. These synthetic pipelines
check counts and sums, use temporary SQLite files and PostgreSQL temporary tables, and
leave existing source data unchanged. They isolate database throughput; they do not
represent markdown processing, uploads, or a complete production-site import.

The initial managed implementation added 8–17% to PostgreSQL stream time and 37% to
cached SQLite insert time. Mandatory per-row Fiber switching and operation locking were
removed from these paths. Fork barriers remain around resource lifetime transitions;
reopenable SQLite operations remain protected. Benchmark results for the revised
implementation against `b33564c4b9e` (the narrow, proven fork fix) follow below.

Local measurements on Ruby 4.0.9 and pg 1.7.0 over a Unix socket used six alternating
pairs of measured processes per streaming/converter case and ten pairs for SQLite/COPY.
Each process warmed up once before its measured run. Times include workload setup and
verification but exclude Ruby startup.

| Workload | Previous median | Revised median | Change |
| --- | --- | --- | --- |
| 1M cached SQLite inserts, 3 columns, 1,000-row transactions, journal off | 567 ms | 567 ms | +0.1% |
| 1M single-integer PostgreSQL hash rows | 400 ms | 340 ms | −15.0% |
| 500k PostgreSQL hash rows with ID, username, 500-byte body, category, timestamp | 602 ms | 563 ms | −6.4% |
| 1M PostgreSQL array rows, ID and username | 377 ms | 333 ms | −11.7% |
| Four concurrent conversion steps, 1M rows total, including shard merges | 699 ms | 680 ms | −2.6% |
| Same conversion without forks | 1.557 s | 1.481 s | −4.9% |
| 1M SQLite rows → PostgreSQL COPY, including SQLite mapping writes | 2.460 s | 2.465 s | +0.2% |

SQLite and COPY elapsed times were indistinguishable within run-to-run variation; paired
95% intervals included both improvement and regression. SQLite median CPU was unchanged;
COPY CPU was 1.890 s versus 1.907 s (+0.9%). These measurements establish parity within
benchmark precision, not a guarantee for every workload or machine. Re-run them when
changing these paths, and supplement them with a representative real migration when
source data is available.

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
