# frozen_string_literal: true

RSpec.describe "Track upcoming changes initializer" do
  context "when enable_upcoming_changes is disabled" do
    before do
      SiteSetting.enable_upcoming_changes = false
      SiteSetting.promote_upcoming_changes_on_status = :stable
    end

    it "does nothing" do
      SiteSetting.expects(:upcoming_change_site_settings).never
      UpcomingChanges::TrackingInitializer.call
    end
  end
end
