# frozen_string_literal: true

describe "Admin Dashboard Redesign" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(current_user)
  end

  describe "date picker" do
    it "defaults to Last 30 days" do
      dashboard.visit

      expect(dashboard).to have_redesigned_toolbar
      expect(dashboard).to have_active_period("last_30_days")
    end

    it "updates the URL when a preset is clicked" do
      dashboard.visit
      dashboard.select_preset("last_7_days")

      expect(page).to have_current_path(/range=last_7_days/)
      expect(dashboard).to have_active_period("last_7_days")
    end

    it "honours the range query param on initial load" do
      page.visit("/admin?range=last_3_months")

      expect(dashboard).to have_active_period("last_3_months")
    end

    it "falls back to default for an invalid range query param" do
      page.visit("/admin?range=bogus_period")

      expect(dashboard).to have_active_period("last_30_days")
    end

    it "rehydrates a custom range from query params" do
      page.visit("/admin?range=custom&start_date=2026-03-01&end_date=2026-04-28")

      expect(dashboard).to have_active_period("custom")
      expect(dashboard).to have_custom_label_text("Mar 1")
      expect(dashboard).to have_custom_label_text("Apr 28")
    end

    it "falls back to default when custom is missing dates" do
      page.visit("/admin?range=custom")

      expect(dashboard).to have_active_period("last_30_days")
    end
  end
end
