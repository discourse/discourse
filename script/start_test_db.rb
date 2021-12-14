#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

BIN = "/usr/lib/postgresql/#{ENV["PG_MAJOR"]}/bin"
DATA = "tmp/test_data/pg"

def run(*args)
  system(*args, exception: true)
end

should_exec = false
while a = ARGV.pop
  if a == "--exec"
    should_exec = true
  else
    raise "Unknown argument #{a}"
  end
end

run "#{BIN}/initdb -D #{DATA}"

run "echo fsync = off >> #{DATA}/postgresql.conf"
run "echo full_page_writes = off >> #{DATA}/postgresql.conf"
run "echo shared_buffers = 500MB >> #{DATA}/postgresql.conf"

if should_exec
  exec "#{BIN}/postmaster -D #{DATA}"
else
  run "#{BIN}/pg_ctl -D #{DATA} start"
end
