# frozen_string_literal: true

# Compares two IntermediateDB files for order-insensitive equality. The
# concurrent converter writes rows in no fixed order, so we sort each table's
# rows and compare a digest instead of diffing the files.
#
# Usage (from the repo root, under the migrations bundle):
#
#   cd migrations/core
#   bundle exec ruby ../tooling/scripts/compare_intermediate_dbs.rb \
#     /path/to/sequential.db /path/to/concurrent.db

require "extralite"
require "digest"

# `schema_migrations.applied_at` is a wall-clock time and always differs.
IGNORED_TABLES = %w[schema_migrations].freeze

def tables(db)
  (db.tables - IGNORED_TABLES).sort
end

def quote(identifier)
  %("#{identifier.gsub('"', '""')}")
end

def table_digest(db, table)
  rows = []
  count = 0
  db.query_array("SELECT * FROM #{quote(table)}") do |row|
    rows << row.map { |value| value.is_a?(String) ? value.b : value.inspect }.join("")
    count += 1
  end
  rows.sort!
  [count, Digest::SHA256.hexdigest(rows.join(""))]
end

seq_path, conc_path = ARGV
abort "usage: compare_intermediate_dbs.rb SEQUENTIAL_DB CONCURRENT_DB" unless seq_path && conc_path

seq = Extralite::Database.new(seq_path)
conc = Extralite::Database.new(conc_path)

seq_tables = tables(seq)
conc_tables = tables(conc)

ok = true

if seq_tables != conc_tables
  ok = false
  warn "Table sets differ:"
  warn "  only in #{seq_path}:  #{(seq_tables - conc_tables).join(", ")}"
  warn "  only in #{conc_path}: #{(conc_tables - seq_tables).join(", ")}"
end

(seq_tables & conc_tables).each do |table|
  seq_count, seq_digest = table_digest(seq, table)
  conc_count, conc_digest = table_digest(conc, table)

  if seq_digest == conc_digest
    puts "  ok    #{table.ljust(32)} #{seq_count} rows"
  else
    ok = false
    puts "  DIFF  #{table.ljust(32)} sequential=#{seq_count} rows, concurrent=#{conc_count} rows"
  end
end

puts(ok ? "\nIdentical (order-insensitive)." : "\nDifferences found.")
exit(ok ? 0 : 1)
