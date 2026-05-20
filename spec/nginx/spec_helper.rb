# frozen_string_literal: true

# Minimal rspec config for the nginx test suite.
#
# Deliberately does NOT load rails_helper: these tests don't need Rails,
# the database, fabricators, or any of the main spec/ infrastructure. The
# suite spawns a real nginx subprocess plus a tiny WEBrick mock upstream
# and asserts on what nginx forwards / serves.
#
# Run with:
#   bundle exec rspec spec/nginx/
#
# Skips itself if nginx isn't on PATH (e.g. local dev machines without
# nginx installed). CI is expected to provide nginx.

require "rspec"

$LOAD_PATH.unshift(File.expand_path("support", __dir__))
require "nginx_harness"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  nginx_available = ENV["DISABLE_NGINX_TESTS"].nil? && system("which nginx >/dev/null 2>&1")

  unless nginx_available
    raise "nginx not found on PATH but NGINX_TESTS_REQUIRED is set" if ENV["NGINX_TESTS_REQUIRED"]
    config.before(:suite) do
      warn "[nginx specs] skipping: nginx not found on PATH " \
             "(set NGINX_TESTS_REQUIRED=1 to fail instead)"
    end
    config.filter_run_excluding(:nginx)
    # Mark all examples in this directory as nginx specs by default
    config.define_derived_metadata(file_path: %r{spec/nginx/}) { |meta| meta[:nginx] = true }
  end
end
