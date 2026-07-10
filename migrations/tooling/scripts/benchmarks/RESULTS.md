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

## Upload hot-path patches — before/after (`DiscoursePatches`)

The upload-pipeline harness above (`upload_creator_profile.rb`,
`upload_worker_scaling.rb`) profiled where a `create_for` spends its time and
pointed at four migration-only short-circuits, now implemented in
`Migrations::Importer::Uploads::DiscoursePatches`:

1. `synchronous_commit=off` for the run (COMMIT no longer waits on a WAL fsync)
2. `user_uploads` find-or-create → one `INSERT … ON CONFLICT DO NOTHING`
3. the constant system uploader `User` memoized instead of reloaded per upload
4. the `DistributedMutex` around `create_for` bypassed (single-writer import)

Both scripts take `UPLOAD_BENCH_PATCHES=1` to apply the patches, so the numbers
below are the same corpus run with the flag off then on.

> Same shared dev box as the sections above (20 cores, `ruby 3.4.9 +YJIT`, local
> Postgres over a unix socket with the stock `synchronous_commit=on`, local
> `FileStore::LocalStore`, `RAILS_ENV=test`, `force_optimize` on). Single runs on
> a shared box — read the shapes, not the last digit.

### Per-`create_for` SQL profile (`upload_creator_profile.rb`, seed 9000)

Per-upload SQL cost, patches off vs on:

```
type         queries/upload   redis rt   SQL ms/upload   % of create_for   create_for ms/upload
attachment   12 -> 8          3 -> 0     19.2 -> 1.15    43.6% -> 4.7%      44.0 -> 24.5   (-44%)
jpg          12 -> 8          3 -> 0     19.3 -> 1.45    13.0% -> 1.2%     148.6 -> 119.7  (cooking-bound, noisy)
png          12 -> 8          3 -> 0     19.0 -> 0.93    11.4% -> 0.6%     (cooking-bound)
```

- The three `COMMIT`s per upload go from **5.9 ms each to ~0.05 ms each** — the
  WAL fsync is gone, which is ~100% of the old SQL cost. The write transactions
  also drop from **3 to 2**: collapsing the `user_uploads` find-or-create into a
  single upsert removes a whole `BEGIN`/`COMMIT` pair on top of the `UserUpload
  Load` SELECT.
- The `User Load` (from `UploadValidator#user&.staff?`) and the `UserUpload Load`
  are gone (4 statements/upload removed), and Redis round-trips go 3 -> 0.
- For an **attachment** (no image cooking) this is the whole story: SQL falls from
  44% of the call to under 5% and `create_for` wall time drops ~44%. For a
  **JPEG/PNG** the ~18 ms of fsync it removes is small next to the ~120-320 ms of
  ImageMagick/oxipng cooking (which this PR deliberately does not touch), so the
  per-file wall barely moves — the win there is CPU/latency headroom, not wall.

### End-to-end pipeline throughput (`upload_worker_scaling.rb`, 8 workers, batch 4)

```
workload       items   items/s off   items/s on   note
attachments      64    29.8 - 36.9   34.6 - 39.7  writer/fsync-bound, ~+8-16%
images           48    14.6 - 16.9   18.2 - 21.3  cooking-bound + noisy, still faster on
```

Patched is faster in every matched run. Attachments are the clean signal (their
cost is the writer thread plus the per-upload commits); images vary a lot
run-to-run because the wall is dominated by convert/oxipng, but freeing the
Postgres commit latency the workers serialize on still lifts aggregate
throughput. Read attachments as the honest headline (~10-15%); the per-`create_for`
profile above is the controlled measurement.
