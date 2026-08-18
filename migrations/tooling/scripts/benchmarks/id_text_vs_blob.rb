#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares storing the XXH3-128 content-hash ids of the IntermediateDB as
# 24-char base64 TEXT (current: Digest::XXH3_128bits.base64digest) vs 16-byte
# binary BLOB (Digest::XXH3_128bits.digest).
#
# Two SQLite schemas, identical apart from the id representation, are filled
# with the same underlying hash values and measured for: bulk insert rate,
# index build time, file/table/index size (via dbstat), point lookups, JOIN
# throughput and the shard-merge pattern (ATTACH + INSERT OR IGNORE) used by
# the converter when it consolidates per-fork shard DBs into the run DB.
#
# Row counts and the temp directory are configurable via env vars:
#
#   SOURCE_ROWS=5000000 REFERENCE_ROWS=20000000 SHARD_COUNT=4 \
#   LOOKUP_SAMPLE=100000 BENCH_TMPDIR=/path/with/space \
#   ruby id_text_vs_blob.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "extralite-bundle", require: "extralite"
  gem "digest-xxhash"
end

require "digest/xxhash"
require "fileutils"
require "tmpdir"

SOURCE_ROWS = Integer(ENV.fetch("SOURCE_ROWS", 5_000_000))
REFERENCE_ROWS = Integer(ENV.fetch("REFERENCE_ROWS", 20_000_000))
SHARD_COUNT = Integer(ENV.fetch("SHARD_COUNT", 4))
LOOKUP_SAMPLE = Integer(ENV.fetch("LOOKUP_SAMPLE", 100_000))
BATCH_SIZE = Integer(ENV.fetch("BATCH_SIZE", 1000))
SEED = Integer(ENV.fetch("SEED", 42))

# TEXT keeps the current base64digest, BLOB switches to the raw 16-byte digest.
# Both derive from the same input string so the two variants hash identical
# underlying values and stay directly comparable.
VARIANTS = [
  { name: "TEXT", column_type: "TEXT", id: ->(input) { Digest::XXH3_128bits.base64digest(input) } },
  { name: "BLOB", column_type: "BLOB", id: ->(input) { Digest::XXH3_128bits.digest(input) } },
].freeze

def open_db(path)
  db = Extralite::Database.new(path)
  db.pragma(
    busy_timeout: 60_000, # 60 seconds
    journal_mode: "wal",
    synchronous: "off",
    temp_store: "memory",
    locking_mode: "normal",
    cache_size: -10_000, # 10_000 pages
  )
  db
end

def create_schema(db, column_type)
  db.execute(<<~SQL)
    CREATE TABLE sources (
      id       #{column_type} NOT NULL PRIMARY KEY,
      filename TEXT,
      filesize INTEGER
    )
  SQL
  db.execute(<<~SQL)
    CREATE TABLE refs (
      id        INTEGER NOT NULL PRIMARY KEY,
      upload_id #{column_type}
    )
  SQL
end

# Mirrors Migrations::Database::Connection: prepared statement, deferred
# transactions committed every BATCH_SIZE rows.
def bulk_insert(db, sql, count)
  stmt = db.prepare(sql)
  db.execute("BEGIN DEFERRED TRANSACTION")
  count.times do |i|
    stmt.execute(yield(i))
    if (i + 1) % BATCH_SIZE == 0
      db.execute("COMMIT")
      db.execute("BEGIN DEFERRED TRANSACTION")
    end
  end
  db.execute("COMMIT") if db.transaction_active?
  stmt.close
end

def measure
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  [result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start]
end

def checkpoint_size(db, path)
  db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
  File.size(path) + (File.exist?("#{path}-wal") ? File.size("#{path}-wal") : 0)
end

# Per-table / per-index byte breakdown. dbstat needs SQLITE_ENABLE_DBSTAT_VTAB;
# guard gracefully when the bundled SQLite was built without it.
def dbstat_breakdown(db)
  db.query_array("SELECT name, SUM(pgsize) FROM dbstat GROUP BY name ORDER BY 2 DESC").to_h
rescue Extralite::Error
  nil
end

def human_bytes(bytes)
  units = %w[B KB MB GB]
  value = bytes.to_f
  unit = units.shift
  while value >= 1024 && units.any?
    value /= 1024
    unit = units.shift
  end
  format("%.1f %s", value, unit)
end

def build_shards(dir, prefix, variant)
  chunk = SOURCE_ROWS / SHARD_COUNT
  overlap = chunk / 10 # rows every shard shares, so INSERT OR IGNORE has work
  paths = []

  SHARD_COUNT.times do |shard|
    path = File.join(dir, "#{prefix}_shard_#{shard}.db")
    paths << path
    db = open_db(path)
    create_schema(db, variant[:column_type])

    # Disjoint slice for this shard plus a shared pool duplicated in every shard.
    indexes = (shard * chunk...(shard + 1) * chunk).to_a
    indexes.concat((0...overlap).to_a) if shard > 0

    bulk_insert(
      db,
      "INSERT OR IGNORE INTO sources (id, filename, filesize) VALUES (?, ?, ?)",
      indexes.size,
    ) do |i|
      idx = indexes[i]
      [variant[:id].call("upload-#{idx}"), "file_#{idx}.png", idx]
    end
    db.close
  end

  paths
end

def run_variant(dir, variant)
  puts "", "== #{variant[:name]} (#{variant[:column_type]} keys) ==", ""
  result = { name: variant[:name] }
  db_path = File.join(dir, "main_#{variant[:name].downcase}.db")
  db = open_db(db_path)
  create_schema(db, variant[:column_type])

  # Precompute the source ids once; references point back into this set.
  source_ids = Array.new(SOURCE_ROWS) { |i| variant[:id].call("upload-#{i}") }

  _, seconds =
    measure do
      bulk_insert(
        db,
        "INSERT INTO sources (id, filename, filesize) VALUES (?, ?, ?)",
        SOURCE_ROWS,
      ) { |i| [source_ids[i], "file_#{i}.png", i] }
    end
  result[:source_insert_rate] = SOURCE_ROWS / seconds
  puts format(
         "  source insert   %10d rows in %8.2fs  (%s rows/s)",
         SOURCE_ROWS,
         seconds,
         format("%.0f", result[:source_insert_rate]),
       )

  rng = Random.new(SEED)
  _, seconds =
    measure do
      bulk_insert(db, "INSERT INTO refs (id, upload_id) VALUES (?, ?)", REFERENCE_ROWS) do |i|
        [i, source_ids[rng.rand(SOURCE_ROWS)]]
      end
    end
  result[:ref_insert_rate] = REFERENCE_ROWS / seconds
  puts format(
         "  ref insert      %10d rows in %8.2fs  (%s rows/s)",
         REFERENCE_ROWS,
         seconds,
         format("%.0f", result[:ref_insert_rate]),
       )

  _, seconds = measure { db.execute("CREATE INDEX idx_refs_upload_id ON refs (upload_id)") }
  result[:index_build_seconds] = seconds
  puts format("  ref index build %31.2fs", seconds)

  breakdown = dbstat_breakdown(db)
  result[:dbstat] = breakdown

  # Point lookups: a fixed random sample of ids fetched by primary key.
  lookup_rng = Random.new(SEED + 1)
  sample = Array.new(LOOKUP_SAMPLE) { source_ids[lookup_rng.rand(SOURCE_ROWS)] }
  lookup_stmt = db.prepare("SELECT filename FROM sources WHERE id = ?")
  lookup_stmt.mode = :splat
  _, seconds = measure { sample.each { |id| lookup_stmt.bind(id).next } }
  lookup_stmt.close
  result[:lookup_rate] = LOOKUP_SAMPLE / seconds
  puts format(
         "  point lookups   %10d ids  in %8.2fs  (%s lookups/s)",
         LOOKUP_SAMPLE,
         seconds,
         format("%.0f", result[:lookup_rate]),
       )

  join_count, seconds =
    measure do
      db.query_single_splat("SELECT COUNT(*) FROM refs r JOIN sources s ON r.upload_id = s.id")
    end
  result[:join_seconds] = seconds
  result[:join_rate] = REFERENCE_ROWS / seconds
  puts format(
         "  join count      %10d rows in %8.2fs  (%s rows/s)",
         join_count,
         seconds,
         format("%.0f", result[:join_rate]),
       )

  file_size = checkpoint_size(db, db_path)
  result[:file_size] = file_size
  puts format("  db file size    %31s", human_bytes(file_size))
  db.close

  # Shard-merge: 4 shards with overlapping id sets consolidated into a fresh DB
  # with INSERT OR IGNORE, matching Connection#merge_database.
  shard_paths = build_shards(dir, variant[:name].downcase, variant)
  merged_path = File.join(dir, "merged_#{variant[:name].downcase}.db")
  merged = open_db(merged_path)
  create_schema(merged, variant[:column_type])
  merged.execute("CREATE INDEX idx_refs_upload_id ON refs (upload_id)")

  _, seconds =
    measure do
      shard_paths.each do |shard_path|
        merged.execute("ATTACH DATABASE ? AS merge_source", shard_path)
        merged.execute("INSERT OR IGNORE INTO main.sources SELECT * FROM merge_source.sources")
        merged.execute("DETACH DATABASE merge_source")
      end
    end
  merged_rows = merged.query_single_splat("SELECT COUNT(*) FROM sources")
  result[:merge_seconds] = seconds
  result[:merged_rows] = merged_rows
  merged.close
  shard_paths.each { |p| FileUtils.rm_f([p, "#{p}-wal", "#{p}-shm"]) }
  FileUtils.rm_f([merged_path, "#{merged_path}-wal", "#{merged_path}-shm"])
  FileUtils.rm_f([db_path, "#{db_path}-wal", "#{db_path}-shm"])
  puts format(
         "  shard merge     %10d rows in %8.2fs  (%d shards)",
         merged_rows,
         seconds,
         SHARD_COUNT,
       )

  result
end

def pct_delta(text_value, blob_value)
  return "n/a" if text_value.nil? || blob_value.nil? || text_value.zero?
  format("%+.1f%%", (blob_value - text_value) / text_value.to_f * 100)
end

puts "",
     "id storage benchmark: TEXT (base64digest) vs BLOB (raw digest)",
     "Extralite SQLite version: #{Extralite.sqlite3_version}",
     "sources=#{SOURCE_ROWS} references=#{REFERENCE_ROWS} shards=#{SHARD_COUNT} lookups=#{LOOKUP_SAMPLE}",
     ""

base = ENV["BENCH_TMPDIR"] || File.join(__dir__, "tmp")
FileUtils.mkdir_p(base)
dir = Dir.mktmpdir("id_bench", base)

results = {}
begin
  VARIANTS.each { |variant| results[variant[:name]] = run_variant(dir, variant) }
ensure
  FileUtils.remove_entry(dir)
end

text = results["TEXT"]
blob = results["BLOB"]

puts "", "== Summary (BLOB relative to TEXT) ==", ""
puts format("%-22s %14s %14s %10s", "metric", "TEXT", "BLOB", "delta")
rows = [
  ["source insert rows/s", text[:source_insert_rate], blob[:source_insert_rate], :rate],
  ["ref insert rows/s", text[:ref_insert_rate], blob[:ref_insert_rate], :rate],
  ["ref index build s", text[:index_build_seconds], blob[:index_build_seconds], :seconds],
  ["lookups/s", text[:lookup_rate], blob[:lookup_rate], :rate],
  ["join s", text[:join_seconds], blob[:join_seconds], :seconds],
  ["merge s", text[:merge_seconds], blob[:merge_seconds], :seconds],
  ["db file size", text[:file_size], blob[:file_size], :bytes],
]
rows.each do |label, t, b, kind|
  case kind
  when :rate
    puts format(
           "%-22s %14s %14s %10s",
           label,
           format("%.0f", t),
           format("%.0f", b),
           pct_delta(t, b),
         )
  when :seconds
    puts format(
           "%-22s %14s %14s %10s",
           label,
           format("%.2f", t),
           format("%.2f", b),
           pct_delta(t, b),
         )
  when :bytes
    puts format("%-22s %14s %14s %10s", label, human_bytes(t), human_bytes(b), pct_delta(t, b))
  end
end

if text[:dbstat] && blob[:dbstat]
  puts "", "dbstat breakdown (bytes):", ""
  puts format("%-22s %14s %14s", "object", "TEXT", "BLOB")
  (text[:dbstat].keys | blob[:dbstat].keys).each do |name|
    puts format(
           "%-22s %14s %14s",
           name,
           human_bytes(text[:dbstat][name].to_i),
           human_bytes(blob[:dbstat][name].to_i),
         )
  end
else
  puts "", "dbstat not available in this SQLite build (no per-object breakdown)."
end
