#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "extralite-bundle"
end

require "etc"
require "extralite"
require "tempfile"

SQL_TABLE = <<~SQL
  CREATE TABLE users (
    id          INTEGER,
    name        TEXT,
    email       TEXT,
    created_at  DATETIME
  )
SQL
SQL_INSERT = "INSERT INTO users VALUES (?, ?, ?, ?)"
USER = [1, "John", "john@example.com", "2023-12-29T11:10:04Z"].freeze
ROW_COUNT = Etc.nprocessors * 200_000

def create_extralite_db(path, initialize: false)
  db = Extralite::Database.new(path)
  db.pragma(
    busy_timeout: 60_000, # 60 seconds
    journal_mode: "wal",
    synchronous: "off",
  )
  db.execute(SQL_TABLE) if initialize
  db
end

def with_db_path
  tempfile = Tempfile.new
  db = create_extralite_db(tempfile.path, initialize: true)
  db.close

  yield tempfile.path

  db = create_extralite_db(tempfile.path)
  row_count = db.query_single_splat("SELECT COUNT(*) FROM users")
  puts "Row count: #{row_count}" if row_count != ROW_COUNT
  db.close
ensure
  tempfile.close
  tempfile.unlink
end

class SingleWriter
  def initialize(db_path, row_count)
    @row_count = row_count

    @db = create_extralite_db(db_path)
    @stmt = @db.prepare(SQL_INSERT)
  end

  def write
    @row_count.times { @stmt.execute(USER) }
    @stmt.close
    @db.close
  end
end

class ForkedSameDbWriter
  def initialize(db_path, row_count)
    @row_count = row_count
    @db_path = db_path
    @pids = []

    setup_forks
  end

  def setup_forks
    fork_count = Etc.nprocessors
    split_row_count = @row_count / fork_count

    fork_count.times do
      @pids << fork do
        db = create_extralite_db(@db_path)
        stmt = db.prepare(SQL_INSERT)

        Signal.trap("USR1") do
          split_row_count.times { stmt.execute(USER) }
          stmt.close
          db.close
          exit
        end

        sleep
      end
    end

    sleep(1)
  end

  def write
    @pids.each { |pid| Process.kill("USR1", pid) }
    Process.waitall
  end
end

class ForkedMultiDbWriter
  def initialize(db_path, row_count)
    @row_count = row_count
    @complete_db_path = db_path
    @pids = []
    @db_paths = []

    @db = create_extralite_db(db_path)

    setup_forks
  end

  def setup_forks
    fork_count = Etc.nprocessors
    split_row_count = @row_count / fork_count

    fork_count.times do |i|
      db_path = "#{@complete_db_path}-#{i}"
      @db_paths << db_path

      @pids << fork do
        db = create_extralite_db(db_path, initialize: true)
        stmt = db.prepare(SQL_INSERT)

        Signal.trap("USR1") do
          split_row_count.times { stmt.execute(USER) }
          stmt.close
          db.close
          exit
        end

        sleep
      end
    end

    sleep(2)
  end

  def write
    @pids.each { |pid| Process.kill("USR1", pid) }
    Process.waitall

    @db_paths.each do |db_path|
      @db.execute("ATTACH DATABASE ? AS db", db_path)
      @db.execute("INSERT INTO users SELECT * FROM db.users")
      @db.execute("DETACH DATABASE db")
    end

    @db.close
  end
end

LABEL_WIDTH = 25

def benchmark(label, label_width = 15)
  print "#{label} ..."
  label = label.ljust(label_width)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  time_diff = sprintf("%.4f", finish - start).rjust(9)
  print "\r#{label} #{time_diff} seconds\n"
end

puts "", "Benchmarking write performance", ""

with_db_path do |db_path|
  single_writer = SingleWriter.new(db_path, ROW_COUNT)
  benchmark("single writer", LABEL_WIDTH) { single_writer.write }
end

with_db_path do |db_path|
  forked_same_db_writer = ForkedSameDbWriter.new(db_path, ROW_COUNT)
  benchmark("forked writer - same DB", LABEL_WIDTH) { forked_same_db_writer.write }
end

with_db_path do |db_path|
  forked_multi_db_writer = ForkedMultiDbWriter.new(db_path, ROW_COUNT)
  benchmark("forked writer - multi DB", LABEL_WIDTH) { forked_multi_db_writer.write }
end
