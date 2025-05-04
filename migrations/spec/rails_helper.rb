# frozen_string_literal: true

# we need to require the rails_helper from core to load the Rails environment
require_relative "../../spec/rails_helper"

require_relative "../migrations"

::Migrations.configure_zeitwerk
::Migrations.enable_i18n

require "rspec-multi-mock"

Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure { |config| config.mock_with MultiMock::Adapter.for(:rspec, :mocha) }
