#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"
require "benchmark"
require "tempfile"

gemfile(true) do
  source "https://rubygems.org"

  gem "extralite-bundle", require: "extralite"
  gem "sqlite3"
  gem "duckdb"
end

ROW_COUNT = 50_000_000
SOME_DATA = ["The quick, brown fox jumps over a lazy dog.", 1_234_567_890].freeze

def with_db_path
  tempfile = Tempfile.new
  yield tempfile.path
ensure
  tempfile.close
  tempfile.unlink
end

module Sqlite
  TRANSACTION_SIZE = 1000
  CREATE_TABLE_SQL = <<~SQL
    CREATE TABLE foo
    (
        id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        some_text   TEXT,
        some_number INTEGER
    )
  SQL
  INSERT_SQL = "INSERT INTO foo (some_text, some_number) VALUES (?, ?)"

  class Sqlite3Benchmark
    def initialize(row_count)
      @row_count = row_count
      @tempfile = Tempfile.new

      @connection = SQLite3::Database.new(@tempfile.path)
      @connection.journal_mode = "wal"
      @connection.synchronous = "off"
      @connection.temp_store = "memory"
      @connection.locking_mode = "normal"
      @connection.cache_size = -10_000 # 10_000 pages

      @connection.execute(CREATE_TABLE_SQL)
      @stmt = @connection.prepare(INSERT_SQL)

      @statement_counter = 0
    end

    def run
      @row_count.times { insert(SOME_DATA) }

      close
    end

    private

    def insert(*parameters)
      begin_transaction if @statement_counter == 0

      @stmt.execute(*parameters)

      if (@statement_counter += 1) > TRANSACTION_SIZE
        commit_transaction
        @statement_counter = 0
      end
    end

    def begin_transaction
      return if @connection.transaction_active?
      @connection.transaction(:deferred)
    end

    def commit_transaction
      return unless @connection.transaction_active?
      @connection.commit
    end

    def close
      commit_transaction
      @stmt.close
      @connection.close

      @tempfile.close
      @tempfile.unlink
    end
  end

  class ExtraliteBenchmark
    def initialize(row_count)
      @row_count = row_count
      @tempfile = Tempfile.new

      @connection = Extralite::Database.new(@tempfile.path)
      @connection.pragma(
        journal_mode: "wal",
        synchronous: "off",
        temp_store: "memory",
        locking_mode: "normal",
        cache_size: -10_000, # 10_000 pages
      )

      @connection.execute(CREATE_TABLE_SQL)
      @stmt = @connection.prepare(INSERT_SQL)

      @statement_counter = 0
    end

    def run
      @row_count.times { insert(SOME_DATA) }

      close
    end

    private

    def insert(*parameters)
      begin_transaction if @statement_counter == 0

      @stmt.execute(*parameters)

      if (@statement_counter += 1) > TRANSACTION_SIZE
        commit_transaction
        @statement_counter = 0
      end
    end

    def begin_transaction
      return if @connection.transaction_active?
      @connection.execute("BEGIN DEFERRED TRANSACTION")
    end

    def commit_transaction
      return unless @connection.transaction_active?
      @connection.execute("COMMIT")
    end

    def close
      commit_transaction
      @stmt.close
      @connection.close

      @tempfile.close
      @tempfile.unlink
    end
  end
end

class DuckDbBenchmark
  CREATE_TABLE_SQL = <<~SQL
    CREATE TABLE foo
    (
        id          INTEGER NOT NULL PRIMARY KEY,
        some_text   TEXT,
        some_number INTEGER
    )
  SQL

  def initialize(row_count)
    @row_count = row_count
    @tempfile = Tempfile.new
    FileUtils.rm(@tempfile.path)

    @db = DuckDB::Database.open(@tempfile.path)
    @connection = @db.connect

    @connection.query(CREATE_TABLE_SQL)
    @appender = @connection.appender("foo")
  end

  def run
    @row_count.times do |id|
      @appender.begin_row
      @appender.append(id)
      @appender.append(SOME_DATA[0])
      @appender.append(SOME_DATA[1])
      @appender.end_row
    end

    close
  end

  private

  def close
    @appender.close
    @connection.close
    @db.close
  end
end

Benchmark.bm(15) do |x|
  x.report("SQLite3") { Sqlite::Sqlite3Benchmark.new(ROW_COUNT).run }
  x.report("Extralite") { Sqlite::ExtraliteBenchmark.new(ROW_COUNT).run }
  x.report("DuckDB") { DuckDbBenchmark.new(ROW_COUNT).run }
end
