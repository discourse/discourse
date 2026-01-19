# frozen_string_literal: true

RSpec.describe UpcomingChanges::AutoPromotionInitializer, type: :multisite do
  context "when enable_upcoming_changes is enabled" do
    before do
      SiteSetting.enable_upcoming_changes = true
      SiteSetting.upcoming_change_verbose_logging = true

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

    it "promotes changes on sites that satisfy promotion criteria" do
      test_multisite_connection("default") do
        SiteSetting.enable_upload_debug_mode = false
        SiteSetting.promote_upcoming_changes_on_status = :beta

        UpcomingChanges::AutoPromotionInitializer.call

        expect(SiteSetting.enable_upload_debug_mode).to be(true)
      end

      # beta status doesn't meet stable threshold, so should not be promoted
      test_multisite_connection("second") do
        SiteSetting.enable_upload_debug_mode = false
        SiteSetting.promote_upcoming_changes_on_status = :stable

        UpcomingChanges::AutoPromotionInitializer.call

        expect(SiteSetting.enable_upload_debug_mode).to be(false)
      end
    end
  end
end
