# frozen_string_literal: true

describe "Promote upcoming changes initializer", type: :multisite do
  context "when enable_upcoming_changes is enabled" do
    before do
      SiteSetting.enable_upcoming_changes = true
      SiteSetting.upcoming_change_verbose_logging = true

      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :stable,
            impact_type: "feature",
            impact_role: "admins",
          },
        },
      )
    end

    it "works for multisites that satisfy promotion criteria" do
      test_multisite_connection("default") do
        expect(SiteSetting.enable_upload_debug_mode).to be(false)
      end
      test_multisite_connection("second") do
        expect(SiteSetting.enable_upload_debug_mode).to be(false)
      end

      UpcomingChanges::AutoPromotionInitializer.call

      test_multisite_connection("default") do
        expect(SiteSetting.enable_upload_debug_mode).to be(true)
      end
      test_multisite_connection("second") do
        expect(SiteSetting.enable_upload_debug_mode).to be(true)
      end
    end
  end
end
