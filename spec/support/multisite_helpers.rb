# frozen_string_literal: true

# Helpers and hooks for multisite specs (tagged `type: :multisite`).

module MultisiteHelpers
  # Normally we `use_transactional_fixtures` to clear out a database after a test
  # runs. However, this does not apply to tests done for multisite. The second time
  # a test runs you can end up with stale data that breaks things. This method will
  # force a rollback after using a multisite connection.
  def test_multisite_connection(name)
    RailsMultisite::ConnectionManagement.with_connection(name) do
      ActiveRecord::Base.transaction(joinable: false) do
        yield
        raise ActiveRecord::Rollback
      end
    end
  end
end

RSpec.configure do |config|
  config.include(MultisiteHelpers)

  config.before(:each, type: :multisite) do
    Rails.configuration.multisite = true # rubocop:disable Discourse/NoDirectMultisiteManipulation

    RailsMultisite::ConnectionManagement.config_filename = "spec/fixtures/multisite/two_dbs.yml"

    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
  end

  config.after(:each, type: :multisite) do
    ActiveRecord::Base.connection_handler.clear_all_connections!
    Rails.configuration.multisite = false # rubocop:disable Discourse/NoDirectMultisiteManipulation
    RailsMultisite::ConnectionManagement.clear_settings!
    ActiveRecord::Base.establish_connection
  end
end
