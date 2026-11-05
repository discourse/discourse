# frozen_string_literal: true

require "bundler/setup"
require "migrations-importer"
require "json"
require "tmpdir"

# The standalone harness supplies the only host constant needed to load CopyStep.
# All writes go to temporary SQLite files and a PostgreSQL temporary table.
module Discourse
  SYSTEM_USER_ID = -1 unless const_defined?(:SYSTEM_USER_ID)
end

module CopyRowsBenchmark
  ROWS = Integer(ENV.fetch("ROWS", "1000000"))
  MODE = ARGV.fetch(0, "copy")

  class Database < Migrations::Importer::DiscourseDB
    private

    def database_configuration
      {
        host: ENV.fetch("PGHOST", "/var/run/postgresql"),
        dbname: ENV.fetch("PGDATABASE", "discourse_development"),
      }
    end
  end

  class Reporter < Migrations::Reporting::Reporter
    def report_progress(*)
    end

    def report_progress_begin(*)
    end
  end

  class Records < Migrations::Importer::CopyStep
    rows_query "SELECT * FROM records"
    total_rows_query "SELECT COUNT(*) FROM records"
    table_name "benchmark_copy_records"
    column_names %i[id username]

    public :fetch_rows # rubocop:disable Style/AccessModifierDeclarations -- Avoid adding a forwarding method to the benchmark.

    private

    def after_commit_of_inserted_rows(rows)
      rows.each do |row|
        @intermediate_db.insert("INSERT INTO mappings VALUES (?, ?)", [row[:id], row[:id]])
      end
    end

    if MODE == "rows"
      def update_progressbar
      end
    end
  end

  def self.verify(actual, expected)
    raise "Expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
  end
end

include CopyRowsBenchmark
raise ArgumentError, "Expected rows or copy" unless %w[rows copy].include?(MODE)

Dir.mktmpdir("mt-copy-rows-") do |directory|
  sqlite =
    Migrations::Database::Connection.new(
      path: File.join(directory, "records.db"),
      journal_mode: "off",
    )
  sqlite.execute("CREATE TABLE records (id INTEGER, username TEXT)")
  sqlite.execute("CREATE TABLE mappings (original_id INTEGER, discourse_id INTEGER)")
  ROWS.times { |id| sqlite.insert("INSERT INTO records VALUES (?, ?)", [id, "username"]) }
  sqlite.commit_transaction
  if MODE == "copy"
    database = Database.new
    database.query_array("CREATE TEMP TABLE benchmark_copy_records (id bigint, username text)").to_a
  end

  Integer(ENV.fetch("ROUNDS", "7")).times do |round|
    sqlite.execute("DELETE FROM mappings")
    database&.query_array("TRUNCATE benchmark_copy_records")&.to_a
    step = Records.new(sqlite, database, nil, nil)
    step.reporter = Migrations::Reporting::Reporter::StepHandle.new(Reporter.new, 1)
    GC.start
    allocations = GC.stat(:total_allocated_objects)
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if MODE == "rows"
      count = 0
      step.fetch_rows.each_slice(1000) { |batch| count += batch.size }
    else
      step.execute
    end
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu
    allocations = GC.stat(:total_allocated_objects) - allocations

    if MODE == "rows"
      CopyRowsBenchmark.verify(count, ROWS)
    else
      CopyRowsBenchmark.verify(sqlite.count("SELECT COUNT(*) FROM mappings"), ROWS)
      CopyRowsBenchmark.verify(
        database.query_array("SELECT COUNT(*), SUM(id) FROM benchmark_copy_records").to_a,
        [[ROWS, ROWS * (ROWS - 1) / 2]],
      )
    end
    puts JSON.generate(mode: MODE, round:, rows: ROWS, wall:, cpu:, allocations:)
    STDOUT.flush
  end
ensure
  database&.close
  sqlite&.close
end
