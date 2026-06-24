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
  row_count.times.map do |id|
    name = SecureRandom.hex(10)
    { id:, name:, email: "#{name}@example.com", created_at: Time.now.utc.iso8601 }
  end
end

def insert_extralite_regular(stmt, users)
  users.each { |user| stmt.execute(user[:id], user[:name], user[:email], user[:created_at]) }
end

def insert_extralite_index(stmt, users)
  users.each { |user| stmt.execute(user) }
end

def insert_extralite_named(stmt, users)
  users.each { |user| stmt.execute(user) }
end

def insert_sqlite3_regular(stmt, users)
  users.each { |user| stmt.execute(user[:id], user[:name], user[:email], user[:created_at]) }
end

def insert_sqlite3_named(stmt, users)
  users.each { |user| stmt.execute(user) }
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

users = create_users(1_000)
users_indexed =
  users.map do |user|
    { 1 => user[:id], 2 => user[:name], 3 => user[:email], 4 => user[:created_at] }
  end
users_array = users.map { |user| [user[:id], user[:name], user[:email], user[:created_at]] }

Benchmark.ips do |x|
  x.config(time: 10, warmup: 2)
  x.report("Extralite regular") { insert_extralite_regular(extralite_stmt_regular, users) }
  x.report("Extralite named") { insert_extralite_named(extralite_stmt_named, users) }
  x.report("Extralite index") { insert_extralite_index(extralite_stmt_regular, users_indexed) }
  x.report("Extralite array") { insert_extralite_index(extralite_stmt_regular, users_array) }
  x.report("SQLite3 regular") { insert_sqlite3_regular(sqlite3_stmt_regular, users) }
  x.report("SQLite3 named") { insert_sqlite3_named(sqlite3_stmt_named, users) }
  x.compare!
end

extralite_stmt_regular.close
extralite_stmt_named.close
extralite_db.close

sqlite3_stmt_regular.close
sqlite3_stmt_named.close
sqlite3_db.close
