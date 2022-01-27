#!/usr/bin/env ruby
# frozen_string_literal: true

BIN = "/usr/lib/postgresql/#{ENV["PG_MAJOR"]}/bin"
DATA = "/tmp/test_data/pg"

def run(*args)
  system(*args, exception: true)
end

should_setup = true
should_run = true
should_exec = false
while a = ARGV.pop
  if a == "--skip-setup"
    should_setup = false
  elsif a == "--skip-run"
    should_run = false
  elsif a == "--exec"
    should_exec = true
  else
    raise "Unknown argument #{a}"
  end
end

if should_setup
  run "#{BIN}/initdb -D #{DATA}"

  run "echo fsync = off >> #{DATA}/postgresql.conf"
  run "echo full_page_writes = off >> #{DATA}/postgresql.conf"
  run "echo shared_buffers = 500MB >> #{DATA}/postgresql.conf"
end

if should_exec
  exec "#{BIN}/postmaster -D #{DATA}"
elsif should_run
  run "#{BIN}/pg_ctl -D #{DATA} start"
end
