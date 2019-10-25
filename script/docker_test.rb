# frozen_string_literal: true

# This script is run in the discourse_test docker image
# Available environment variables:
# => NO_UPDATE        disables updating the source code within the discourse_test docker image
# => COMMIT_HASH      used by the discourse_test docker image to load a specific commit of discourse
#                     this can also be set to a branch, e.g. "origin/tests-passed"
# => RUN_SMOKE_TESTS  executes the smoke tests instead of the regular tests from docker.rake
# => WARMUP_TMP_FOLDER runs a single spec to warmup the tmp folder and obtain accurate results when profiling specs.
# See lib/tasks/docker.rake and lib/tasks/smoke_test.rake for more information

puts "travis_fold:end:starting_docker_container" if ENV["TRAVIS"]

def log(message)
  puts "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
end

def run_or_fail(command)
  log(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  exit 1 unless $?.exitstatus == 0
end

unless ENV['NO_UPDATE']
  puts "travis_fold:start:pulling_latest_discourse" if ENV["TRAVIS"]

  run_or_fail("git reset --hard")

  run_or_fail("git pull")

  checkout = ENV['COMMIT_HASH'] || "HEAD"
  run_or_fail("git checkout #{checkout}")

  puts "travis_fold:end:pulling_latest_discourse" if ENV["TRAVIS"]
  puts "travis_fold:start:bundle" if ENV["TRAVIS"]

  run_or_fail("bundle")

  puts "travis_fold:end:bundle" if ENV["TRAVIS"]
end

if ENV['WARMPUP_TMP_FOLDER']
  run_or_fail('bundle exec rspec ./spec/requests/users_controller_spec.rb:222')
end

log("Running tests")
if ENV['RUN_SMOKE_TESTS']
  run_or_fail("bundle exec rake smoke:test")
else
  run_or_fail("bundle exec rake docker:test")
end
