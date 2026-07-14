# frozen_string_literal: true

# Mock framework setup: rspec-mocks and Mocha used together via rspec-multi-mock.

# To avoid erasing `any_instance` from Mocha
require "rspec/mocks/syntax"
RSpec::Mocks::Syntax.singleton_class.define_method(:enable_should) { |*| nil }
RSpec::Mocks::Syntax.singleton_class.define_method(:disable_should) { |*| nil }

RSpec::Mocks::ArgumentMatchers.remove_method(:hash_including) # We’re currently relying on the version from Webmock

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
    mocks.syntax = :expect
  end
  config.mock_with MultiMock::Adapter.for(:mocha, :rspec)

  config.include Mocha::API
end
