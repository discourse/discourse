# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../dummy/config/environment', __FILE__)
require 'rspec/rails'

# Development dependencies
require 'json-schema'
require 'faker'
require 'factory_girl_rails'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
support_directory = File.expand_path('../dummy/spec/support', __FILE__)
Dir["#{support_directory}/**/*.rb"].each { |f| require f }

# In Rails 4.0.x add the following to the top of the rails_helper file after
# Rails has been required. This will raise an exception if there are any pending
# schema changes. Users will still be required to manually keep the development
# and test environments in sync.
ActiveRecord::Migration.check_pending! if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR == 0

# With Rails 4.1+ there was an exciting new feature. Users no longer need to
# keep the development and test environments in sync. To take advantage of this
# add the following to the top of the rails_helper file after Rails has been
# required:
ActiveRecord::Migration.maintain_test_schema! if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR == 1

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = '#{::Rails.root}/spec/fixtures'

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
end
