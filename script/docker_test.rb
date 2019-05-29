# frozen_string_literal: true

# This script is run in the discourse_test docker image
# Available environment variables:
# => NO_UPDATE        disables updating the source code within the discourse_test docker image
# => COMMIT_HASH      used by the discourse_test docker image to load a specific commit of discourse
#                     this can also be set to a branch, e.g. "origin/tests-passed"
# => RUN_SMOKE_TESTS  executes the smoke tests instead of the regular tests from docker.rake
# See lib/tasks/docker.rake and lib/tasks/smoke_test.rake for more information

puts "travis_fold:end:starting_docker_container" if ENV["TRAVIS"]

def log(msg)
  STDERR.puts "#{Time.now.iso8601}: #{msg}"
end

def run_or_fail(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  exit 1 unless $?.exitstatus == 0
end

unless ENV['NO_UPDATE']
  puts "travis_fold:start:pulling_latest_discourse" if ENV["TRAVIS"]

  log("Reseting git repository")
  run_or_fail("git reset --hard")

  log("Pulling git repository")
  run_or_fail("git pull")

  log("Checking out git branch")
  checkout = ENV['COMMIT_HASH'] || "HEAD"
  run_or_fail("git checkout #{checkout}")

  puts "travis_fold:end:pulling_latest_discourse" if ENV["TRAVIS"]
  puts "travis_fold:start:bundle" if ENV["TRAVIS"]

  log("Run bundler")
  run_or_fail("bundle")

  puts "travis_fold:end:bundle" if ENV["TRAVIS"]
end

log("Running tests")
if ENV['RUN_SMOKE_TESTS']
  run_or_fail("bundle exec rake smoke:test")
else
  run_or_fail("bundle exec rake docker:test")
end
