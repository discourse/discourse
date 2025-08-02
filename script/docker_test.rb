# frozen_string_literal: true

# This script is to be run in the `discourse/discourse_test:release` docker image.

require "optparse"

options = {}

OptionParser
  .new do |opts|
    opts.banner = "Usage: ruby script/docker_test.rb [options]"

    opts.on(
      "--checkout-ref CHECKOUT_REF",
      "Checks out the working tree to a specified commit hash or branch. If not specified, defaults to 'origin/tests-passed'.",
    ) { |v| options[:checkout_ref] = v }

    opts.on(
      "--run-smoke-tests",
      "Executes the smoke tests instead of the regular tests from docker.rake. See lib/tasks/smoke_test.rake for more information.",
    ) { options[:run_smoke_tests] = true }

    opts.on(
      "--no-checkout",
      "Does not check out the working tree when this option is passed. By default, the working tree is checked out to the latest commit on the 'origin/tests-passed' branch.",
    ) { options[:no_checkout] = true }

    opts.on("--no-tests", "Does not execute any tests") { options[:no_tests] = true }

    opts.on_tail("-h", "--help", "Displays usage information") do
      puts opts
      exit
    end
  end
  .parse!

no_checkout = options.has_key?(:no_checkout) ? options[:no_checkout] : ENV["NO_UPDATE"]
checkout_ref = options.has_key?(:checkout_ref) ? options[:checkout_ref] : ENV["COMMIT_HASH"]
run_smoke_tests =
  options.has_key?(:run_smoke_tests) ? options[:run_smoke_tests] : ENV["RUN_SMOKE_TESTS"]
no_tests = options.has_key?(:no_tests) ? options[:no_tests] : false

def log(message)
  puts "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
end

def run_or_fail(command)
  log(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  exit 1 unless $?.exitstatus == 0
end

unless no_checkout
  run_or_fail("git reset --hard")
  run_or_fail("git fetch")
  run_or_fail("LEFTHOOK=0 git checkout #{checkout_ref || "origin/tests-passed"}")
  run_or_fail("bundle")
end

unless no_tests
  if run_smoke_tests
    log("Running smoke tests")
    run_or_fail("bundle exec rake smoke:test")
  else
    log("Running tests")
    run_or_fail("bundle exec rake docker:test")
  end
end
