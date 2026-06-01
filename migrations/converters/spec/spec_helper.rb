# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Boot the host harness with the cwd at the application root (see migrations-core
# spec_helper for why); Discourse resolves some Zeitwerk ignore paths relative to it.
if ENV["MIGRATIONS_RAILS"]
  rails_root = File.expand_path("../../..", __dir__)
  Dir.chdir(rails_root) { require File.join(rails_root, "spec", "rails_helper") }
end

require "migrations-converters"

Migrations.enable_i18n
Migrations.apply_global_config

require "rspec-multi-mock"

# Shared spec support (matchers, helpers) lives in the core gem.
Dir[File.expand_path("../../core/spec/support/**/*.rb", __dir__)].each { |f| require f }
Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.mock_with MultiMock::Adapter.for(:rspec, :mocha)
  config.filter_run_excluding(:rails) unless ENV["MIGRATIONS_RAILS"]
end
