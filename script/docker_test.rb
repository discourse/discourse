def run_or_fail(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  exit 1 unless $?.exitstatus == 0
end

unless ENV['NO_UPDATE']
  run_or_fail("git remote update")

  checkout = ENV['COMMIT_HASH'] || "HEAD"
  run_or_fail("git checkout #{checkout}")
  run_or_fail("bundle")
end

run_or_fail("bundle exec rake docker:test")
