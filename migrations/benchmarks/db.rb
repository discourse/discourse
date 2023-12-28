#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "extralite-bundle", github: "digital-fabric/extralite"
  gem "sqlite3"
end

require "extralite"
require "benchmark"
require "time"
require "securerandom"

ROW_COUNT = 1_000_000

def generate_hashes
  ROW_COUNT.times.map do |id|
    name = SecureRandom.hex(10)
    { id: id, name: name, email: "#{name}@example.com", created_at: Time.now.utc.iso8601 }
  end
end

def with_extralite
  db = Extralite::Database.new(":memory:")
  db.execute(<<~SQL)
    CREATE TABLE users (
      id          INTEGER PRIMARY KEY,
      name        TEXT,
      email       TEXT,
      created_at  DATETIME
    )
  SQL
  yield db
ensure
  db.close
end

def with_sqlite
  db = SQLite3::Database.new(":memory:")
  db.execute(<<~SQL)
    CREATE TABLE users (
      id          INTEGER PRIMARY KEY,
      name        TEXT,
      email       TEXT,
      created_at  DATETIME
    )
  SQL
  yield db
ensure
  db.close
end

def insert_hash(db)
  USERS_AS_HASH.each do |user|
    db.execute("INSERT INTO users VALUES (:id, :name, :email, :created_at)", user)
  end
end

def extralite_insert_hash
  with_extralite { |db| insert_hash(db) }
end

def sqlite_insert_hash
  with_sqlite { |db| insert_hash(db) }
end

def insert_data(db)
  USERS_AS_DATA.each do |user|
    db.execute("INSERT INTO users VALUES (:id, :name, :email, :created_at)", user)
  end
end

def insert_data_as_hash(db)
  USERS_AS_DATA.each do |user|
    db.execute("INSERT INTO users VALUES (:id, :name, :email, :created_at)", user.to_h)
  end
end

def extralite_insert_data
  with_extralite { |db| insert_data(db) }
end

def extralite_insert_data_as_hash
  with_extralite { |db| insert_data_as_hash(db) }
end

def sqlite_insert_data_as_hash
  with_sqlite { |db| insert_data_as_hash(db) }
end

puts "",
     "Extralite SQLite version: #{Extralite.sqlite3_version}",
     "SQLite version: #{SQLite3::SQLITE_VERSION}",
     ""

Benchmark.bm(10) do |x|
  x.report("hash") { generate_hashes }
  x.report("data") { generate_data }
end

puts "", "Generating data...", ""

USERS_AS_HASH = generate_hashes
USERS_AS_DATA = generate_data

GC.start

Benchmark.bm(35) do |x|
  x.report("extralite_insert_hash") { extralite_insert_hash }
  x.report("extralite_insert_data") { extralite_insert_data }
  x.report("extralite_insert_data_as_hash") { extralite_insert_data_as_hash }

  x.report("sqlite_insert_hash") { sqlite_insert_hash }
  x.report("sqlite_insert_data_as_hash") { sqlite_insert_data_as_hash }
end
