#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "benchmark-ips"
  gem "extralite-bundle"
  gem "sqlite3"
end

require "extralite"
require "benchmark/ips"
require "time"
require "securerandom"

User = Data.define(:id, :name, :email, :created_at)

USER_HASH =
  begin
    name = SecureRandom.hex(10)
    { id: 1, name:, email: "#{name}@example.com", created_at: Time.now.utc.iso8601 }
  end

USER_DATA =
  User.new(
    id: USER_HASH[:id],
    name: USER_HASH[:name],
    email: USER_HASH[:email],
    created_at: USER_HASH[:created_at],
  )

SQL_TABLE = <<~SQL
  CREATE TABLE users (
    id          INTEGER,
    name        TEXT,
    email       TEXT,
    created_at  DATETIME
  )
SQL
SQL_INSERT = "INSERT INTO users VALUES (?, ?, ?, ?)"
SQL_INSERT_NAMED = "INSERT INTO users VALUES (:id, :name, :email, :created_at)"

def create_extralite_db
  db = Extralite::Database.new(":memory:")
  db.execute(SQL_TABLE)
  db
end

def create_sqlite3_db
  db = SQLite3::Database.new(":memory:")
  db.execute(SQL_TABLE)
  db
end

def create_users(row_count)
  row_count.times.map { |id| }
end

def insert_extralite_regular(stmt, user)
  stmt.execute(user.id, user.name, user.email, user.created_at)
end

def insert_extralite_hash(stmt, user)
  stmt.execute(user)
end

def insert_extralite_data(stmt, user)
  stmt.execute(user)
end

def insert_sqlite3_regular(stmt, user)
  stmt.execute(user.id, user.name, user.email, user.created_at)
end

def insert_sqlite3_hash(stmt, user)
  stmt.execute(user)
end

puts "",
     "Extralite SQLite version: #{Extralite.sqlite3_version}",
     "SQLite version: #{SQLite3::SQLITE_VERSION}",
     ""

extralite_db = create_extralite_db
extralite_stmt_regular = extralite_db.prepare(SQL_INSERT)
extralite_stmt_named = extralite_db.prepare(SQL_INSERT_NAMED)

sqlite3_db = create_sqlite3_db
sqlite3_stmt_regular = sqlite3_db.prepare(SQL_INSERT)
sqlite3_stmt_named = sqlite3_db.prepare(SQL_INSERT_NAMED)

Benchmark.ips do |x|
  x.config(time: 10, warmup: 2)
  x.report("Extralite regular") { insert_extralite_regular(extralite_stmt_regular, USER_DATA) }
  x.report("Extralite hash") { insert_extralite_hash(extralite_stmt_named, USER_HASH) }
  x.report("Extralite data") { insert_extralite_data(extralite_stmt_regular, USER_DATA) }
  x.report("Extralite data/array") do
    insert_extralite_data(extralite_stmt_regular, USER_DATA.deconstruct)
  end
  x.report("SQLite3 regular") { insert_sqlite3_regular(sqlite3_stmt_regular, USER_DATA) }
  x.report("SQLite3 hash") { insert_sqlite3_hash(sqlite3_stmt_named, USER_HASH) }
  x.report("SQLite3 data/hash") { insert_sqlite3_hash(sqlite3_stmt_named, USER_DATA.to_h) }
  x.compare!
end

extralite_stmt_regular.close
extralite_stmt_named.close
extralite_db.close

sqlite3_stmt_regular.close
sqlite3_stmt_named.close
sqlite3_db.close
