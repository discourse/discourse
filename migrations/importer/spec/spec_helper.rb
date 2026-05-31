# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require File.expand_path("../../../spec/rails_helper", __dir__) if ENV["MIGRATIONS_RAILS"]

require "migrations-importer"

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
