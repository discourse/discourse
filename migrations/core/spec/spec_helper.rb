# frozen_string_literal: true

require "tempfile"
require "tmpdir"

require "migrations-core"

Migrations.enable_i18n
Migrations.apply_global_config

require "rspec-multi-mock"

Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure { |config| config.mock_with MultiMock::Adapter.for(:rspec, :mocha) }
