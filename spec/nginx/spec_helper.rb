# frozen_string_literal: true

# Minimal rspec config for the nginx test suite.
#
# Deliberately does NOT load rails_helper: these tests don't need Rails,
# the database, fabricators, or any of the main spec/ infrastructure. The
# suite spawns a real nginx subprocess plus a tiny WEBrick mock upstream
# and asserts on what nginx forwards / serves.
#
# Run with:
#   spec/nginx/run.sh
#
# Skips integration examples if nginx isn't on PATH (e.g. local dev machines
# without nginx installed). Pure-Ruby support specs still run. CI is expected
# to provide nginx.

require "rspec"

$LOAD_PATH.unshift(File.expand_path("support", __dir__))
require "nginx_executable"
require "nginx_harness"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.define_derived_metadata(file_path: %r{spec/nginx/(?!support/)}) do |meta|
    meta[:nginx] = true
  end

  # Probe the same executable the harness will spawn (Process.spawn /
  # execvp resolution), not a separate `which` lookup that could disagree.
  nginx_available = ENV["DISABLE_NGINX_TESTS"].nil? && Nginx::Support::NginxExecutable.available?

  unless nginx_available
    raise "nginx not found on PATH but NGINX_TESTS_REQUIRED is set" if ENV["NGINX_TESTS_REQUIRED"]

    config.before(:suite) do
      warn "[nginx specs] skipping nginx integration examples: nginx not found on PATH " \
             "(set NGINX_TESTS_REQUIRED=1 to fail instead)"
    end

    # Skip per-example rather than via filter_run_excluding(:nginx): an
    # exclusion filter is bypassed when the developer supplies an
    # inclusion filter (e.g. run.sh --example basic), which would let an
    # integration example run and crash on Process.spawn("nginx"). A
    # before-hook keyed on the :nginx tag skips regardless of selection.
    config.before(:each, :nginx) { skip "nginx not found on PATH" }
  end
end
