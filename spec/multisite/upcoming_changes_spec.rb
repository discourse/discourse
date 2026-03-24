# frozen_string_literal: true

RSpec.describe "Multisite UpcomingChanges cache", type: :multisite do
  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :permanent,
          impact_type: "other",
          impact_role: "developers",
        },
      },
    )
    Rails.stubs(:public_path).returns(File.join(Rails.root, "spec", "fixtures"))
  end

  after do
    %w[default second].each do |site|
      RailsMultisite::ConnectionManagement.with_connection(site) do
        Discourse.cache.delete(UpcomingChanges.current_statuses_cache_key)
        Discourse.cache.delete(UpcomingChanges.permanent_upcoming_changes_cache_key)
      end
    end
    clear_mocked_upcoming_change_metadata
  end

  it "keeps current_statuses tied to each site's upcoming_change_events" do
    test_multisite_connection("default") do
      Discourse.cache.delete(UpcomingChanges.current_statuses_cache_key)
      UpcomingChangeEvent.where(upcoming_change_name: "enable_upload_debug_mode").delete_all
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "enable_upload_debug_mode",
        event_data: {
          "previous_value" => "stable",
          "new_value" => "permanent",
        },
      )

      expect(UpcomingChanges.current_statuses["enable_upload_debug_mode"][:status]).to eq(
        "permanent",
      )
    end

    test_multisite_connection("second") do
      Discourse.cache.delete(UpcomingChanges.current_statuses_cache_key)
      UpcomingChangeEvent.where(upcoming_change_name: "enable_upload_debug_mode").delete_all

      expect(UpcomingChanges.current_statuses).to eq({})
    end
  end

  it "caches current_statuses on the default site" do
    test_multisite_connection("default") do
      Discourse.cache.delete(UpcomingChanges.current_statuses_cache_key)
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "multisite_cache_setting",
        event_data: {
          "previous_value" => nil,
          "new_value" => "beta",
        },
      )

      allow(DB).to receive(:query).and_call_original
      2.times { UpcomingChanges.current_statuses }
      expect(DB).to have_received(:query).once
    end
  end

  it "caches current_statuses on the second site" do
    test_multisite_connection("second") do
      Discourse.cache.delete(UpcomingChanges.current_statuses_cache_key)

      allow(DB).to receive(:query).and_call_original
      2.times { UpcomingChanges.current_statuses }
      expect(DB).to have_received(:query).once
    end
  end

  it "caches permanent_upcoming_changes on the default site" do
    test_multisite_connection("default") do
      Discourse.cache.delete(UpcomingChanges.permanent_upcoming_changes_cache_key)
      allow(UpcomingChanges::List).to receive(:call).and_call_original
      2.times { UpcomingChanges.permanent_upcoming_changes }
      expect(UpcomingChanges::List).to have_received(:call).once
    end
  end

  it "caches permanent_upcoming_changes on the second site" do
    test_multisite_connection("second") do
      Discourse.cache.delete(UpcomingChanges.permanent_upcoming_changes_cache_key)
      allow(UpcomingChanges::List).to receive(:call).and_call_original
      2.times { UpcomingChanges.permanent_upcoming_changes }
      expect(UpcomingChanges::List).to have_received(:call).once
    end
  end
end
