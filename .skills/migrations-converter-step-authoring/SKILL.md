---
name: migrations-converter-step-authoring
description: Use when writing or reviewing conversion steps (source system → IntermediateDB) in a converter's steps/ directory — covers the source/processor DSL, reads_table, partitioning, progress and error tracking, and IntermediateDB writes
---

# Writing conversion steps

A conversion step reads items from a source system and writes them to the
IntermediateDB. Framework: `migrations/core/lib/migrations/conversion/step.rb`
plus `step/source.rb` and `step/processor.rb`.

**Don't confuse this with the importer framework** — importer steps
(`Migrations::Importer::Step` / `CopyStep`, `depends_on`, `rows_query`,
`transform_row`) read the IntermediateDB and write the final Discourse
database. `CopyStep` exists only there.

## Anatomy

```ruby
# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CategoryUsers < Conversion::Step
        source { reads_table "category_users", where: "user_id > 0" }

        processor do
          def process(item)
            IntermediateDB::CategoryUser.create(
              category_id: item[:category_id],
              last_seen_at: item[:last_seen_at],
              notification_level: item[:notification_level],
              user_id: item[:user_id],
            )
          end
        end
      end
    end
  end
end
```

A step builds **two separate role objects** from its DSL blocks:

- `source { ... }` — enumerates items. Has `@source_db` (the step's own
  connection, injected via the converter's `step_args`), `@settings`, and
  `@chunk` when partitioned. Its `cleanup` closes `@source_db`.
- `processor { ... }` — handles one item at a time. Has `@settings` and
  `@tracker`; **no source-DB access**. Anything the processor needs must be
  embedded in the item (see `site_settings.rb` for the lazy-enumerator
  pattern) or built in `setup`.
- `helpers { ... }` — a module mixed into **both** roles; pure functions only.

The roles are deliberately distinct classes — a processor calling a source
method is a `NoMethodError`, not a design option. Inside the blocks use plain
`def` (they are `class_eval`'d; `define_method` would capture step-level state
across the role boundary).

## Source

`reads_table "name", where: "...", order: :id` gives you `items`
(`SELECT * FROM name WHERE ...`) and `max_progress` (the row count) for free —
a plain table copy writes neither method.

Override `items` when you need specific columns, a join, or a computed value:

```ruby
source do
  def max_progress
    @source_db.count "SELECT COUNT(*) FROM badges"
  end

  def items
    @source_db.query <<~SQL
      SELECT b.*, u.url AS image_url
        FROM badges b LEFT JOIN uploads u ON u.id = b.image_upload_id
       ORDER BY b.id
    SQL
  end
end
```

- Items are row hashes with symbol keys. A lazy enumerator
  (`rows.lazy.map { ... }`) is fine.
- `max_progress` must count the same units `items` yields, or the progress
  bar drifts — it is computed once, up front, in the parent process.

## Processor

- `process(item)` — the one required method. Write records with the generated
  `IntermediateDB::X.create(...)` models
  (`core/lib/migrations/database/intermediate_db/`); enums are under
  `Enums::`. If a column you need doesn't exist there, the schema config is
  the fix — load `.skills/migrations-schema-dsl`.
- `process`'s return value is ignored. Progress and errors flow through
  `@tracker` (see below).
- `setup` — optional; builds per-worker state (e.g.
  `@upload_creator = UploadCreator.new`). It runs after the worker starts,
  never in the constructor (forked workers each need their own state), and it
  **must not write to the IntermediateDB** — `SetupGuard` raises if it tries.

## Progress, warnings, errors

Each item counts as 1 unit of progress by default. Inside `process`:

- `tracker.progress = n` — override this item's weight
- `tracker.log_warning(...)` / `tracker.log_error(message, exception:, details:)` —
  count and persist an `IntermediateDB::LogEntry`

An exception escaping `process` is caught by the runner, logged as an error
with the item as details, and the step **continues with the next item** — one
bad row never kills a step. Step-level failures are aggregated into a single
`ConvertError` at the end of the run.

## Partitioning large steps

A handful of steps are big enough to split across CPU cores:

```ruby
source do
  reads_table "topic_users", where: "user_id > 0"
  partition_by :topic_id
end
```

`partition_by` takes the key — normally one indexed column, an array for a
composite key — and reuses the table and filter from `reads_table`. The
framework computes chunk boundaries in the parent, forks workers that pull
chunks from a shared queue, and merges the per-worker SQLite shards back into
the run database. Generated queries automatically add the chunk range to
`WHERE` **and order by the key**.

Rules:

1. **In a custom `items` query, add `partition_slice` to the `WHERE`
   yourself** (`WHERE #{partition_slice} AND ...`). Miss it and every worker
   reads the whole source — duplicated rows and wrong counts.
2. **Also `ORDER BY` the partition key in a custom query.** Unordered chunk
   reads make the shard-merge index inserts effectively random, which has
   measurably slowed whole runs by ~2x before.
3. **Only partition order-independent steps.** Workers run concurrently and
   shards are merged, so there is no global order across the step. Running
   totals or sequence numbers can't be partitioned. Deduplication can — but
   do it in the source query (`DISTINCT ON`, a window function) and partition
   on the dedup key, never via state in `process`.

## Dependencies and titles

- Steps are discovered automatically (see
  `.skills/migrations-converter-authoring`); there is no list to update.
- `depends_on :other_step` (symbol, sibling step name) is for **correctness
  only** — step B reads what step A wrote. Don't use it for thematic
  ordering. `priority n` nudges scheduling among ready steps (lower first).
- `title "..."` overrides the default title derived from the class name.

## Debugging

```bash
migrations/bin/disco convert <name> --only topic_users --no-fork
```

`--no-fork` runs steps serially in-process, so a breakpoint in `process`
stops in your terminal instead of an unreachable child.

## Review checklist

1. Column mapping in `process` covers every column the IntermediateDB model
   requires; datetimes/booleans go through the generated model (it formats
   them), not hand-rolled SQL
2. Custom `items` on a partitioned step includes `partition_slice` in `WHERE`
   and `ORDER BY` on the partition key
3. Partitioned step is order-independent (no cross-row state in `process`)
4. Per-worker state built in `setup`, not the constructor; no IntermediateDB
   writes in `setup`
5. `max_progress` counts exactly what `items` yields
6. Expected data problems are `tracker.log_warning`/`log_error`, not raises
   (raises work but lose intent — they all become "Failed to process item")
7. `helpers` contain pure functions only; no `define_method` in DSL blocks
8. `depends_on` only where a real read-after-write dependency exists
