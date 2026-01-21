# frozen_string_literal: true

RSpec.describe UpcomingChanges::TrackingInitializer, type: :multisite do
  context "when enable_upcoming_changes is enabled" do
    before do
      SiteSetting.enable_upcoming_changes = true
      SiteSetting.upcoming_change_verbose_logging = true
      SiteSetting.promote_upcoming_changes_on_status = :stable

      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :beta,
            impact_type: "feature",
            impact_role: "admins",
          },
        },
      )
    end

    it "tracks changes across all sites" do
      test_multisite_connection("default") do
        Fabricate(:admin)
        SiteSetting.enable_upcoming_changes = true
        SiteSetting.promote_upcoming_changes_on_status = :stable
        UpcomingChangeEvent.where(upcoming_change_name: :enable_upload_debug_mode).delete_all

        UpcomingChanges::TrackingInitializer.call

        expect(
          UpcomingChangeEvent.exists?(
            upcoming_change_name: :enable_upload_debug_mode,
            event_type: :added,
          ),
        ).to be(true)
      end

      test_multisite_connection("second") do
        Fabricate(:admin)
        SiteSetting.enable_upcoming_changes = true
        SiteSetting.promote_upcoming_changes_on_status = :stable
        UpcomingChangeEvent.where(upcoming_change_name: :enable_upload_debug_mode).delete_all

        UpcomingChanges::TrackingInitializer.call

        expect(
          UpcomingChangeEvent.exists?(
            upcoming_change_name: :enable_upload_debug_mode,
            event_type: :added,
          ),
        ).to be(true)
      end
    end
  end
end
