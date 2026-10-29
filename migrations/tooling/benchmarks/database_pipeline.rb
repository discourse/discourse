# frozen_string_literal: true

require "bundler/setup"
require "migrations-converters"
require "migrations-importer"
require "json"
require "tmpdir"

# Run this same file with each revision's BUNDLE_GEMFILE. Only temporary databases
# and PostgreSQL session-local tables are written. PGHOST/PGDATABASE select the source.
module DatabasePipelineBenchmark
  ROWS = Integer(ENV.fetch("ROWS", "200000"))
  SETTINGS = {
    host: ENV.fetch("PGHOST", "/var/run/postgresql"),
    dbname: ENV.fetch("PGDATABASE", "discourse_development"),
  }.freeze
  BODY = ("body text " * 10).freeze
  INSERT = "INSERT INTO records VALUES (?, ?, ?)"

  class ImportDatabase < Migrations::Importer::DiscourseDB
    private

    def database_configuration
      SETTINGS
    end
  end

  class Records < Migrations::Conversion::Step
    source do
      def max_progress
        ROWS
      end

      def items
        @database = Migrations::Converters::Adapter::Postgres.new(SETTINGS)
        @database.query(
          "SELECT n AS id, 'username_' || n AS username, repeat('body text ', 10) AS body FROM generate_series(1, #{ROWS}) n",
        )
      end

      def cleanup
        @database&.close
      end
    end

    processor do
      def process(item)
        Migrations::Database::IntermediateDB.insert(INSERT, item[:id], item[:username], item[:body])
        tracker.progress = 1
      end
    end
  end

  class QuietReporter < Migrations::Reporting::Reporter
    %i[
      report_start
      report_notice
      report_progress_begin
      report_concurrency
      report_progress
      report_finish
    ].each { |method| define_method(method) { |*| } }
  end

  def self.verify_count(actual, expected)
    raise "Expected #{expected} rows, got #{actual}" unless actual == expected
  end

  def self.with_sqlite
    Dir.mktmpdir("mt-benchmark-") do |directory|
      connection =
        Migrations::Database::Connection.new(
          path: File.join(directory, "records.db"),
          journal_mode: "off",
        )
      connection.execute("CREATE TABLE records (id INTEGER, username TEXT, body TEXT)")
      begin
        yield connection
      ensure
        connection.close
      end
    end
  end

  def self.sqlite
    with_sqlite do |connection|
      ROWS.times { |index| connection.insert(INSERT, [index, "username", BODY]) }
      connection.commit_transaction
      verify_count(connection.count("SELECT COUNT(*) FROM records"), ROWS)
    end
  end

  def self.stream(mode)
    if mode == "stream_array"
      database = ImportDatabase.new
      rows =
        database.query_array(
          "SELECT n AS id, 'username_' || n AS username FROM generate_series(1, #{ROWS}) n",
        )
    else
      database = Migrations::Converters::Adapter::Postgres.new(SETTINGS)
      columns =
        (
          if mode == "stream_wide"
            "n AS id, 'username_' || n AS username, repeat('body text ', 50) AS body, n % 7 AS category_id, now() AS created_at"
          else
            "n AS id"
          end
        )
      rows = database.query("SELECT #{columns} FROM generate_series(1, #{ROWS}) n")
    end
    count = 0
    rows.each { count += 1 }
    verify_count(count, ROWS)
  ensure
    database&.close
  end

  def self.convert(no_fork: false)
    Dir.mktmpdir("mt-benchmark-") do |directory|
      migrations_path = File.join(directory, "schema")
      FileUtils.mkdir_p(migrations_path)
      File.write(File.join(migrations_path, "001-schema.sql"), <<~SQL)
        CREATE TABLE records (id INTEGER, username TEXT, body TEXT);
        CREATE TABLE log_entries (created_at TEXT, type INTEGER, message TEXT, exception TEXT, details TEXT);
      SQL
      path = File.join(directory, "intermediate.db")
      Migrations::Database.migrate(path, migrations_path:)
      shards = Migrations::Conversion::ShardManager.new(canonical_path: path, migrations_path:)
      options = { path: }
      # The pre-lifecycle implementation has no explicit reopenable option.
      if Migrations::Database::Connection
           .instance_method(:initialize)
           .parameters
           .any? { |_, name| name == :reopenable }
        options[:reopenable] = true
      end
      writer = Migrations::Database::Connection.new(**options)
      steps = 4.times.map { |index| const_get("Records#{index}") }
      Migrations::Conversion::StepScheduler.new(
        step_classes: steps,
        reporter: QuietReporter.new,
        step_factory: ->(step_class) { step_class.new },
        shard_manager: shards,
        writer:,
        budget: 4,
        no_fork:,
      ).run
      verify_count(writer.count("SELECT COUNT(*) FROM records"), ROWS * 4)
      verify_count(writer.query_value("SELECT SUM(id) FROM records"), ROWS * (ROWS + 1) / 2 * 4)
    ensure
      writer&.close
      shards&.cleanup
    end
  end

  def self.import
    database = ImportDatabase.new
    database.query_array(
      "CREATE TEMP TABLE benchmark_records (id bigint, username text, body text)",
    ).to_a
    with_sqlite do |connection|
      ROWS.times { |index| connection.insert(INSERT, [index, "username", BODY]) }
      connection.commit_transaction
      rows =
        Enumerator.new do |yielder|
          connection.query("SELECT * FROM records") { |row| yielder << row }
        end
      connection.execute(
        "CREATE TABLE id_mapping (original_id INTEGER PRIMARY KEY, discourse_id INTEGER)",
      )
      copied = 0
      database.copy_data("benchmark_records", %i[id username body], rows) do |inserted, skipped|
        raise "Unexpected skipped rows" if skipped.any?
        inserted.each do |row|
          connection.insert("INSERT INTO id_mapping VALUES (?, ?)", [row[:id], row[:id]])
        end
        copied += inserted.size
      end
      connection.commit_transaction
      verify_count(connection.count("SELECT COUNT(*) FROM id_mapping"), ROWS)
      verify_count(copied, ROWS)
      verify_count(database.query_array("SELECT COUNT(*) FROM benchmark_records").to_a.first, ROWS)
      verify_count(
        database.query_array("SELECT SUM(id) FROM benchmark_records").to_a.first,
        ROWS * (ROWS - 1) / 2,
      )
    end
  ensure
    database&.close
  end

  4.times { |index| const_set("Records#{index}", Class.new(Records)) }
end

mode = ARGV.fetch(0)
Integer(ENV.fetch("ROUNDS", "7")).times do |round|
  GC.start
  allocated = GC.stat(:total_allocated_objects)
  cpu = Process.times
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  case mode
  when "sqlite"
    DatabasePipelineBenchmark.sqlite
  when "convert", "convert_inline"
    DatabasePipelineBenchmark.convert(no_fork: mode == "convert_inline")
  when "import"
    DatabasePipelineBenchmark.import
  when "stream_hash", "stream_wide", "stream_array"
    DatabasePipelineBenchmark.stream(mode)
  else
    raise ArgumentError, "Unknown benchmark: #{mode}"
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  finish_cpu = Process.times
  puts JSON.generate(
         mode:,
         round:,
         rows: DatabasePipelineBenchmark::ROWS,
         wall: elapsed,
         cpu: finish_cpu.to_a.sum - cpu.to_a.sum,
         allocations: GC.stat(:total_allocated_objects) - allocated,
       )
  STDOUT.flush
end
