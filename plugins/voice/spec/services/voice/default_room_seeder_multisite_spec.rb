# frozen_string_literal: true

RSpec.describe Voice::DefaultRoomSeeder, type: :multisite do
  it "keeps schema readiness isolated by site" do
    described_class.instance_variable_set(:@schema_ready, nil)
    SiteSetting.voice_enabled = true
    described_class.ensure!

    test_multisite_connection("second") do
      SiteSetting.voice_enabled = true
      ActiveRecord::Base.connection.remove_column(:voice_rooms, :ephemeral)

      expect { described_class.ensure! }.not_to raise_error
    end
  ensure
    described_class.instance_variable_set(:@schema_ready, nil)
    test_multisite_connection("second") do
      ActiveRecord::Base.connection.schema_cache.clear_data_source_cache!("voice_rooms")
    end
    Voice::Room.reset_column_information
  end
end
