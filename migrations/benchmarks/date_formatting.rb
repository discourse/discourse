#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "extralite-bundle", github: "gschlager/extralite", branch: "binding_unhandled"
end

require "extralite"
require "benchmark"
require "date"
require "time"
require "securerandom"

ROW_COUNT = 1_000_000

def generate_hashes
  ROW_COUNT.times.map do |id|
    name = SecureRandom.hex(10)
    { id: id, name: name, email: "#{name}@example.com", created_at: Time.now.utc }
  end
end

def create_db
  db = Extralite::Database.new(":memory:")
  db.execute(<<~SQL)
    CREATE TABLE users (
      id          INTEGER PRIMARY KEY,
      name        TEXT,
      email       TEXT,
      created_at  DATETIME
    )
  SQL
  db
end

def insert_directly(db)
  USERS.each do |user|
    db.execute("INSERT INTO users VALUES (:id, :name, :email, :created_at)", user)
  end
end

def insert_modified(db)
  users = USERS.map { |user| user.dup.merge(created_at: user[:created_at].iso8601) }
  users.each do |user|
    db.execute("INSERT INTO users VALUES (:id, :name, :email, :created_at)", user)
  end
end

puts "", "Extralite SQLite version: #{Extralite.sqlite3_version}"

puts "", "Generating data...", ""
USERS = generate_hashes

db1 = create_db
db1.on_unhandled_parameter = ->(value) do
  case value
  when Time
    value.iso8601
  when Date
    value.iso8601
  else
    raise "don't know how to handle #{value.class}"
  end
end

db2 = create_db

Benchmark.bm(20) do |x|
  x.report("insert_directly") { insert_directly(db1) }
  x.report("insert_modified") { insert_modified(db2) }
end

db1.close
db2.close
