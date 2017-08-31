# This script is run in the discourse_test docker image
# Available environment variables:
# => COMMIT_HASH    used by the discourse_test docker image to load a specific commit of discourse
#                   this can also be set to a branch, e.g. "origin/tests-passed"
# See lib/tasks/docker.rake for more information

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
