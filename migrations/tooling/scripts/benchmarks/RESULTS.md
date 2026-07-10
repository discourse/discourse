# Benchmark Results

Here are the latest benchmark results. All benchmarks ran with `ruby 3.2.3 (2024-01-18 revision 52bb2ac0a6) [x86_64-linux]`

## database_write.rb

Compares the INSERT speed of SQLite and DuckDB

| Database  | User Time | System Time | Total Time |  Real Time |
|-----------|----------:|------------:|-----------:|-----------:|
| SQLite3   | 99.212731 |    4.883932 | 104.096663 | 104.233575 |
| Extralite | 45.396666 |    4.457247 |  49.853913 |  50.065680 |
| DuckDB    | 49.012140 |   10.210994 |  59.223134 |  52.095679 |

## hash_vs_data.rb

Compares the INSERT speed when the data is bound as Hash or Data class

```
   Extralite regular    868.703k (± 2.2%) i/s -      8.744M in  10.070511s
      Extralite hash    579.753k (± 1.2%) i/s -      5.838M in  10.071266s
      Extralite data    672.752k (± 0.8%) i/s -      6.790M in  10.093191s
Extralite data/array    826.296k (± 0.9%) i/s -      8.318M in  10.067518s
     SQLite3 regular    362.037k (± 0.7%) i/s -      3.628M in  10.021699s
        SQLite3 hash    308.647k (± 1.1%) i/s -      3.111M in  10.081159s
   SQLite3 data/hash    288.747k (± 2.7%) i/s -      2.890M in  10.018335s

Comparison:
   Extralite regular:   868702.8 i/s
Extralite data/array:   826295.7 i/s - 1.05x  slower
      Extralite data:   672752.0 i/s - 1.29x  slower
      Extralite hash:   579753.5 i/s - 1.50x  slower
     SQLite3 regular:   362037.0 i/s - 2.40x  slower
        SQLite3 hash:   308646.7 i/s - 2.81x  slower
   SQLite3 data/hash:   288747.1 i/s - 3.01x  slower
```

## parameter_binding.rb

A similar benchmark that looks at various parameter binding styles, especially in Extralite

```
   Extralite regular    825.159 (± 0.6%) i/s -      8.316k in  10.078450s
     Extralite named    571.135 (± 0.4%) i/s -      5.742k in  10.053796s
     Extralite index    769.273 (± 1.0%) i/s -      7.742k in  10.065238s
     Extralite array    860.549 (± 0.5%) i/s -      8.624k in  10.021749s
     SQLite3 regular    361.745 (± 0.6%) i/s -      3.636k in  10.051588s
       SQLite3 named    307.875 (± 0.6%) i/s -      3.090k in  10.036954s

Comparison:
     Extralite array:      860.5 i/s
   Extralite regular:      825.2 i/s - 1.04x  slower
     Extralite index:      769.3 i/s - 1.12x  slower
     Extralite named:      571.1 i/s - 1.51x  slower
     SQLite3 regular:      361.7 i/s - 2.38x  slower
       SQLite3 named:      307.9 i/s - 2.80x  slower
```

## time_formatting.rb

Fastest way of converting `Time` into `String`?

```
        Time#iso8601      1.084M (± 0.9%) i/s -     10.875M in  10.033905s
       Time#strftime      1.213M (± 1.4%) i/s -     12.200M in  10.056764s
    DateTime#iso8601      2.419M (± 1.8%) i/s -     24.296M in  10.046295s

Comparison:
    DateTime#iso8601:  2419162.1 i/s
       Time#strftime:  1213390.0 i/s - 1.99x  slower
        Time#iso8601:  1083922.8 i/s - 2.23x  slower
```

## write.rb

Compares writing lots of data into a single SQLite database.

```
single writer               43.9766 seconds
forked writer - same DB     53.5112 seconds
forked writer - multi DB     3.0815 seconds
```

## Upload pipeline harness (`upload_corpus.rb`, `upload_worker_scaling.rb`, `upload_creator_profile.rb`)

These three scripts are different from the others above: they need the Discourse
Rails environment (they run the real `Tasks::Uploader` pipeline and
`UploadCreator`), so they bootstrap Bundler the way `disco` does and boot Rails.
They exist to justify two later PRs with measurements instead of guesses: the
adaptive worker-count controller (needs the scaling curves) and any UploadCreator
hot-path patch (only where the profile proves a win).

- `upload_corpus.rb` builds a deterministic corpus (seeded synthetic images +
  binary attachments) plus a matching IntermediateDB SQLite.
- `upload_worker_scaling.rb` drives the pipeline at fixed worker counts and
  reports items/s and CPU busy (from `/proc/stat`). It can also sweep two extra
  dimensions: simulated store latency (`SCALING_STORE_LATENCIES`, a sleep wrapped
  around the local store's `store_upload` — `sleep` releases the GVL, so it models
  S3's worker-parking effect but not aws-sdk CPU or its connection-pool limit) and
  `MAGICK_THREAD_LIMIT` (`SCALING_MAGICK_THREAD_LIMITS`, to compare
  internally-threaded convert against single-threaded convert with more workers).
- `upload_creator_profile.rb` breaks `create_for` down into per-stage
  wall-clock, with optional stackprof / memory_profiler passes.

Run them against a throwaway site only (they create real Upload records and store
files); they refuse unless `UPLOAD_BENCH_I_KNOW=1` and refuse an S3 store unless
`UPLOAD_BENCH_ALLOW_S3=1`:

```
RAILS_ENV=test UPLOAD_BENCH_I_KNOW=1 \
  ruby migrations/tooling/scripts/benchmarks/upload_worker_scaling.rb
```

> **These are small-scale smoke runs on a dev box, not the real numbers.**
> Machine: 20 cores, `ruby 3.4.9 +YJIT`, local Postgres + Redis, local
> `FileStore::LocalStore`, `RAILS_ENV=test`, ImageMagick 7 with
> oxipng/jpegoptim/pngquant present. `force_optimize` is on so the full image
> cooking path runs even under the test env (it is otherwise skipped there).
> Full S3/minio scaling runs, and larger corpora, happen on real infra — the
> point here is that the scripts work and already show the shape of the curves.

### Worker scaling (60 images / 30 attachments, seed 7000)

```
== images ==
  workers   items     ok      secs    items/s     cpu%    cores
  1            60     60     15.87       3.78     16.0      3.2
  4            60     60      8.66       6.93     19.1     3.81
  8            60     60      8.64       6.95     20.4     4.07

== attachments ==
  workers   items     ok      secs    items/s     cpu%    cores
  1            30     30      1.18      25.46      9.8     1.97
  4            30     30      1.18      25.52     10.0     1.99
  8            30     30      1.17      25.59      9.7     1.94

== mixed ==
  workers   items     ok      secs    items/s     cpu%    cores
  1            90     90     15.64       5.76     12.3     2.45
  4            90     90      7.20      12.51     17.5     3.49
  8            90     90      7.12      12.64     16.6     3.31
```

`cores` = fully-busy-core equivalent from `/proc/stat`. What the curves already show:

- **Image throughput plateaus early (~4 workers here), well below the 20 cores.**
  1 -> 4 workers roughly doubles throughput; 4 -> 8 is flat. The adaptive
  controller must not chase `nprocessors`.
- **A single pipeline worker already keeps ~3 cores busy**, because ImageMagick
  and oxipng are internally multi-threaded. Worker count is not core count: the
  controller has to reason about cores busy, not threads spawned.
- **The machine never gets past ~20% CPU even at the plateau.** The image path
  spends most of its Ruby time serialized (GVL + the single SQLite writer + PG
  inserts), so beyond a few workers extra threads contend instead of working.
- **Attachments are flat across all worker counts** (~25 items/s, ~2 cores):
  sha1 + a file copy into the store, no image cooking, bottlenecked on the writer.

> **Follow-up on the same box: the "plateau at 4" above is mostly a measurement
> artifact, not a real ceiling.** Workers pop whole batches, not single rows, and
> the default batch size is 32. A 60-item corpus is only 2 batches, so however
> many workers I asked for, at most ~2 ever had work — the flat 4/8/16 rows were
> starvation. The box gave it away: load average sat around 1.5 and CPU never
> passed ~20% even at the "plateau". Re-running with `SCALING_BATCH_SIZE=4` (so 80
> items = 20 batches, enough to feed every worker) changes the picture, and the
> "controller must not chase nprocessors" lesson above does not survive it.

### Worker scaling with enough batches (batch_size=4, seed 7000)

Store-latency sweep, images and mixed, MAGICK_THREAD_LIMIT unset. The corpus is
sized so items >= batch_size x max_workers, otherwise the run starves as above.

```
images (80 items = 20 batches)
  latency  workers   items/s   cores   cpu%
  0ms         1         4.28    1.52    7.6
  0ms         4        14.57    4.36   21.8
  0ms         8        16.62    5.16   25.8
  0ms        16        16.54    5.39   26.9
  80ms        1         3.25    1.09    5.5
  80ms        4        11.34    3.53   17.6
  80ms        8        15.89    4.87   24.4
  80ms       16        15.74    5.25   26.2

mixed (80 images + 40 attachments = 120 items = 30 batches)
  latency  workers   items/s   cores   cpu%
  0ms         1         6.02    1.46    7.3
  0ms         4        20.56    4.27   21.4
  0ms         8        31.64    7.59   38.0
  0ms        16        36.77    9.38   46.9
  80ms        1         4.03    1.21    6.1
  80ms        4        15.08    3.13   15.6
  80ms        8        24.91    6.27   31.3
  80ms       16        32.97    9.29   46.5
```

What this shows once workers are actually fed:

- **Throughput scales well past 4 workers.** Images roughly 4x from 1 to 8 workers
  (knee around 8, ceiling ~16 items/s); mixed keeps climbing to 16 (~6x, still
  rising there). So the adaptive controller *can* use more than a handful of
  workers — the earlier reading was wrong.
- **The ceiling is neither CPU nor the store.** At the images knee the box is only
  ~27% CPU / ~5.4 of 20 cores. What saturates is the single writer thread plus the
  GVL-serialized Ruby per upload (sha1, AR build, PG insert). That serial section
  is the real cap — more workers stop helping while the machine is 70%+ idle.
- **Simulated store latency moves the knee right, it does not raise the ceiling.**
  80ms of parking per PUT drops throughput at low worker counts (workers sleep
  more) but by 8-16 workers it converges on the same ceiling as 0ms (mixed 32.97
  vs 36.77 at 16 workers; images 15.74 vs 16.54). So the parking effect is real —
  you need more workers to reach the ceiling once each store call blocks — but
  here it doesn't unlock a higher ceiling, because the ceiling is the writer, not
  the store. Real S3 latency is an order of magnitude over a local copy, so the
  knee moves much further right there, which is exactly why production wants more
  workers than a local box does. This models the parking only, not aws-sdk CPU or
  its connection-pool ceiling.

### MAGICK_THREAD_LIMIT: internally-threaded convert vs single-threaded + more workers

images, batch_size=4, no latency. Does capping convert to one thread and running
more pipeline workers beat the default on *total* throughput?

```
  magick   workers   items/s   cores   cpu%
  unset       1         4.24    1.59    8.0
  unset       4        12.79    3.99   19.9
  unset       8        20.50    6.49   32.4
  unset      16        24.10    9.48   47.4
  unset      20        22.41    8.69   43.4
  1           1         4.08    1.40    7.0
  1           4        11.85    4.17   20.8
  1           8        19.08    5.88   29.4
  1          16        22.81    7.50   37.5
  1          20        21.68    7.43   37.1
```

(The limit takes effect: `magick -list resource` reports `Thread: 20` by default
and `Thread: 1` with `MAGICK_THREAD_LIMIT=1`, and the convert subprocesses inherit
our environment.)

- **No, thread_limit=1 does not win on total throughput.** Peak is ~24/s (unset,
  16 workers) vs ~23/s (limit=1, 16 workers) — within noise. Both peak at 16
  workers and both sag a little at 20 (more workers than batches).
- **But capping to 1 thread is nearly free and a bit more core-efficient.** At
  every worker count the two are within ~5% on throughput, yet limit=1 reaches the
  peak on ~7.5 cores against ~9.5 for unset. On these image sizes a single convert
  barely uses more than ~1.5 cores anyway (resize/recompress don't parallelize
  much), so removing its internal threads costs almost nothing and leaves cores
  free. It's a CPU-headroom lever, not a throughput lever.
- **Neither run saturates CPU** (peak ~47% / ~9.5 cores of 20) — same writer
  ceiling as the latency sweep. That is the through-line of both experiments: the
  first thing to tune on this pipeline is the serial writer/handoff, not the
  worker count or the convert threads.

Variance: these are single runs per cell on a shared dev box (other worktrees idle
but present). Cells that should match (e.g. images 8 vs 16 workers at the ceiling)
differ by a few percent, and absolute items/s drift a little between the two runs
above, so read sub-5% differences as noise — the shapes are what hold.

### `create_for` per-stage profile (one file per image tier, seed 9000)

```
DistributedMutex: 0.151 ms/upload (empty lock/unlock, 200x)

== jpg (5 files) ==            ms/file  %create
  downsize!                     92.37    27.2%
  optimize! (oxipng/jpegoptim)  83.49    24.5%
  convert_to_jpeg!              82.77    24.3%
  dominant_color                32.20     9.5%
  target_image_quality          12.22     3.6%
  sha1_generate_digest (x3)      5.18     1.5%
  task_tempfile_copy             1.06     0.3%

== png (3 files) ==            ms/file  %create
  convert_to_jpeg!              67.82    37.4%
  optimize! (oxipng level 3)    38.10    21.0%
  dominant_color                34.62    19.1%
  sha1_generate_digest (x3)      7.30     4.0%
  target_image_quality           6.41     3.5%
  task_tempfile_copy             1.47     0.8%

== attachment (3 files) ==     ms/file  %create
  sha1_generate_digest (x3)     11.92    14.3%
  task_tempfile_copy             1.14     1.4%
```

(Stage times can nest slightly — `extract_image_info!` runs again inside
`convert_to_jpeg!`/`downsize!` — so shares don't sum to exactly 100%.)

### Ranked hypotheses vs. what the profile shows

1. **Triple SHA1 (`generate_digest`) — confirmed 3 calls/upload, but cheap.**
   ~1.5% of a JPEG, ~4% of a PNG. It only looks big for attachments (14%) because
   they do no image work. Not worth patching for images; a small win for
   attachment-heavy imports at best.
2. **DistributedMutex Redis RTT — negligible here.** 0.15 ms/upload for an empty
   lock/unlock, against ~340 ms of image work. (Caveat: this box has local Redis;
   real infra with a network hop will be higher, but still tiny next to cooking.)
3. **`target_image_quality` (`identify %Q`) — modest, 3.5-6.7%.** Real subprocess
   cost, but not a headline.
4. **Dominant-color `convert` subprocess — significant, 9-19%.** The largest
   single "extra" subprocess and the most credible micro-optimization target
   (e.g. folding it into an existing convert pass, or skipping it).
5. **oxipng level 3 (`optimize!`) — large, 21-25%, grows with PNG size.** It is
   doing real compression work; a win would mean tuning the level/threshold, not
   removing it.
6. **Extra full-file tempfile copy in the task — negligible, 0.3-1.4%.** Not a win.

The dominant cost by far is the ImageMagick conversion/downsize/optimize
subprocesses (`convert_to_jpeg!` + `downsize!` + `optimize!` ≈ 75% of a JPEG's
time). These are CPU-bound and already spread across workers, which is exactly
why the scaling curve, not a sha1 patch, is where the leverage is.

stackprof (in-GVL, wall) over a run is dominated by `PG::Connection#exec` (~35%)
and `Digest::Base#update` (~10%); it can't see the subprocess time, which is why
the per-stage wall-clock table above is the primary artifact. memory_profiler
shows `create_for` allocating ~186 KB / 54 retained objects per call — memory is
not a concern.

Environment notes for reproducing: Discourse's ImageMagick policy blocks pseudo
coders like `gradient:`, so the corpus generator uses only the allowed
`xc:`/`+noise` coder; `redis-cli` is absent on this box but `Discourse.redis`
works fine. Nothing blocked a piece of the harness.

### SQL and Redis round-trips per `create_for` (18 images / 12 attachments, seed 9000)

> **Dev-box measurement, not production numbers.** Same box as above: local
> Postgres over a unix socket, `RAILS_ENV=test` (the `discourse_test` DB), local
> Redis. The DB runs with `synchronous_commit=on` and `fsync=on`, so a `COMMIT`
> pays a real WAL fsync — that turns out to dominate everything, see below. The
> profiler subscribes to `sql.active_record`, strips literals/bind placeholders/
> the marginalia comment to collapse each statement to its shape, and counts
> Redis round-trips on the profiling thread via a redis-client middleware. It came
> out of the stackprof reading that put ~35% of the in-GVL time in
> `PG::Connection#exec`; the goal was to find out what that `exec` time actually
> is.

**Every `create_for` fires the same 12 SQL statements, regardless of file type**
(small jpg, large png that gets converted, or a plain attachment — the DB path is
identical, only the image cooking differs). Three of them are writes, each in its
own transaction, so there are **3 `BEGIN`/`COMMIT` pairs = 3 fsyncs per upload**:

| statement (name)      | per upload | ms/call (dev box) | what it is |
|-----------------------|-----------:|------------------:|------------|
| `COMMIT`              | 3          | **5.5 – 8.0**     | WAL fsync; one per write below |
| `BEGIN`              | 3          | 0.07              | opens each write's transaction |
| `Upload Load`         | 1          | 0.23 – 0.27       | sha1 dedup lookup (`… WHERE sha1 = ? LIMIT 1`) |
| `Upload Create`       | 1          | 0.16 – 0.20       | INSERT the upload row |
| `Upload Update`       | 1          | 0.24 – 0.50       | second write: set `url` after the file is stored |
| `User Load`           | 1          | 0.19 – 0.37       | load the (constant) uploader user |
| `UserUpload Load`     | 1          | 0.09 – 0.24       | find-or-create half of the `user_uploads` join |
| `UserUpload Create`   | 1          | 0.12 – 0.48       | INSERT the `user_uploads` join row |

SQL wall time per upload is ~18–26 ms across all four types. Its share of
`create_for` swings only because the image cooking around it does: on an
attachment (no cooking) SQL is ~39% of the call, on a JPEG (~320 ms of
convert/downsize/optimize) it's ~6%.

```
type        queries/file   redis rt/file   SQL ms/file   % of create_for
attachment      12              3              18.4          39.3%
jpg             12              3              19.1           6.0%
gif             12              3              25.6          26.9%
png             12              3              19.7          11.7%
```

**The `COMMIT` fsync is the whole story.** Of the ~19 ms of SQL per upload,
~16–24 ms is the three `COMMIT`s at 5.5–8 ms each; every non-commit statement is
under 0.5 ms. So the stackprof `PG::Connection#exec` ~35% is not query volume and
not AR overhead — it is Ruby blocked on three WAL fsyncs. A direct check on this
box: a single-row `BEGIN/INSERT/COMMIT` costs **5.6 ms**, but 300 inserts wrapped
in one transaction cost **0.054 ms each amortized** — ~100x, all of it the fsync.

**Client vs. server split (raw libpq vs ActiveRecord, same socket).**
pg_stat_statements isn't in this box's `shared_preload_libraries`, so instead the
harness runs the *same* statement two ways: raw `PG::Connection#exec` (server exec
+ protocol round-trip) and `connection.select_all` (adds AR's notification
instrumentation, query-cache check and result type-casting). The gap is the
Ruby/AR overhead per query.

```
query                        raw_us    ar_us   overhead_us   ar_over%
SELECT 1                        8.2     17.6          9.4       53%
uploads by sha1 (indexed)      50.0    102.5         52.6       51%
server exec (EXPLAIN ANALYZE): 0.011 ms
```

So for a read: the server does ~0.01 ms of actual work, the socket round-trip is
tens of µs, and AR roughly doubles that (another ~10–50 µs of Ruby). AR overhead
is real but it is µs against the 5.6 ms fsync — it never shows up next to a
`COMMIT`. The verdict for the "how much is Postgres working vs Ruby/AR overhead"
question: **almost none of the SQL wall time is either the server executing or AR
wrapping the call — it's transaction durability (fsync) on the commits.**

**Redis: 3 round-trips per upload** (single-threaded, so this excludes MessageBus
noise on other threads). Two are `DistributedMutex` lock/unlock around the
create; the third is one more command in the same path. At ~0.09 ms per empty
lock/unlock locally they're negligible here, but each is a network hop on real
infra.

**Ranked skip/batch candidates** (biggest lever first):

1. **Batch many uploads into one transaction — migration-only, huge.** Three
   fsync-bound commits per upload is ~16–24 ms/upload of pure durability latency,
   and it's ~100% of the SQL time. A bulk import that inserts N uploads under one
   transaction (or with `synchronous_commit=off` for the load) turns 3N fsyncs
   into ~1, which the 0.054 ms/insert amortized number says is essentially free.
   This is the single biggest DB win and it does not apply to production, where
   each user upload is its own request and must commit on its own.
2. **The `Upload Update` (url) after the INSERT — mostly absorbed by item 1, not
   independently fixable.** The two-step is there for good reasons: the store path
   depends on `upload.id` (`get_depth_for(id)` picks the `original/2X/` depth
   prefix), which only exists after the INSERT, and a blank `url` is the
   crash-recovery signal — the dedup path treats `url.blank?` as "previous attempt
   failed, destroy and redo". So url-set means file-is-in-the-store, and
   production should keep that. A migration could invert it (reserve ids from the
   sequence up front, compute paths, store files first, INSERT complete rows),
   trading url-less rows for orphaned files on crash — acceptable for a
   re-runnable import, but it's a real behaviour change, not a free win. In
   practice item 1 removes most of this item's cost anyway: inside a batched
   transaction the UPDATE no longer pays its own fsync and is just a ~0.3 ms
   statement.
3. **Skip the sha1 dedup `Upload Load` — migration-only, with a caveat.** The
   `SELECT … WHERE sha1 = ?` (top of `create_for`) is not just dedup — it is what
   makes a re-run of the upload importer idempotent: on the second run it finds
   the existing row and returns early, skipping all three writes/commits. Today we
   rely on Rails for exactly that, so this lookup only becomes skippable if the
   importer's own state (blob-hash ids / files DB) also answers "was this already
   created?" across re-runs. Cheap either way (~0.25 ms, one round-trip).
   Production needs it regardless.
4. **Collapse the `user_uploads` find-or-create into one upsert — migration-only,
   small.** Not a blind INSERT: on a re-run the join row already exists (the
   dedup early-return path in `create_for` does the same find-or-create), so it
   has to stay idempotent. `user_uploads` has a unique index on
   `(upload_id, user_id)`, so `INSERT … ON CONFLICT DO NOTHING` keeps the
   behaviour in one round-trip instead of two, fresh and re-run alike. ~0.15 ms +
   one round-trip per upload.
5. **Memoize / skip the `User Load` — migration-only, small.** The uploader is a
   constant within an import run (usually the mapped author or the system user), so
   reloading the user row every upload is avoidable. ~0.2 ms + one round-trip.
6. **Drop `DistributedMutex` — migration-only, small.** The mutex guards against
   concurrent creates racing on the same sha1; a single-writer import that already
   dedups doesn't need it. Removes 2–3 Redis round-trips per upload. Negligible on
   a local box, more on networked Redis. Production needs it.

Everything in 2–6 is a µs-to-sub-ms saving per upload; item 1 is the one that
matters, and all of it is migration-context. Two constraints shape the list: the
importer must stay re-runnable (we rely on `create_for`'s sha1 lookup to detect
already-created uploads, so items 3 and 4 have to preserve that idempotency), and
the INSERT-then-UPDATE url dance is deliberate crash-recovery, not waste. For
production the takeaway is narrower still: the DB cost of an upload is its
commits, not its SELECTs or AR overhead, and none of the statements are safely
removable there.
