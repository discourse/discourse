# frozen_string_literal: true

require "tempfile"
require "tmpdir"

# When MIGRATIONS_RAILS is set (the integration job, run via the host app's
# bundle), boot the full Discourse test harness so that :rails-tagged specs can
# run. The default, isolated suite runs without Rails.
require File.expand_path("../../../spec/rails_helper", __dir__) if ENV["MIGRATIONS_RAILS"]

require "migrations-core"

Migrations.enable_i18n
Migrations.apply_global_config

require "rspec-multi-mock"

Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.mock_with MultiMock::Adapter.for(:rspec, :mocha)
  config.filter_run_excluding(:rails) unless ENV["MIGRATIONS_RAILS"]
end
