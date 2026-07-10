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

## id_text_vs_blob.rb

Compares storing the XXH3-128 content-hash ids as 24-char base64 TEXT (current
format) vs 16-byte binary BLOB. Ran with `ruby 3.4.9 +YJIT [x86_64-linux]`,
Extralite SQLite 3.53.3, on an i9-13900H (20 threads, 32 GB RAM), DB files on
NVMe. Volumes: 5M source rows, 20M reference rows, 100k point lookups, 4-shard
merge with 10% overlap.

```
metric                           TEXT           BLOB      delta
source insert rows/s            74675          83442     +11.7%
ref insert rows/s             1244109        1422542     +14.3%
ref index build s               20.38          19.51      -4.3%
lookups/s                      207467         301823     +45.5%
join s                          22.73          21.33      -6.1%
merge s                         21.44          19.43      -9.3%
db file size                   1.7 GB         1.3 GB     -22.6%
```

BLOB wins across the board: ~23% smaller DB file, 12-14% faster inserts, 9%
faster shard merges, 45% faster point lookups, 6% faster joins. Nothing gets
slower. The gains come from key width (24 vs 16 bytes) in the PK b-tree and in
every reference index, so they compound with the number of `*upload*_id`
columns. Worth switching to `Digest::XXH3_128bits.digest`; the trade-off is
that ids are no longer human-readable in query output and ad-hoc SQL needs
`x'…'` literals or `hex(id)`.

`dbstat` is not compiled into the bundled Extralite SQLite, so there is no
per-table/per-index size breakdown.

## write.rb

Compares writing lots of data into a single SQLite database.

```
single writer               43.9766 seconds
forked writer - same DB     53.5112 seconds
forked writer - multi DB     3.0815 seconds
```
