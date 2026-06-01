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

    it "picking a sidebar-only preset applies a custom range" do
      today = Date.today
      start_date = today - 6.months + 1.day

      dashboard.visit
      dashboard.open_custom_date_range
      dashboard.select_sidebar_preset("Last 6 months")

      expect(dashboard).to have_active_period("custom")
      expect(page).to have_current_path(
        "/admin?end_date=#{today.strftime("%Y-%m-%d")}&range=custom&start_date=#{start_date.strftime("%Y-%m-%d")}",
      )
      expect(dashboard).to have_custom_label_text(start_date.strftime("%b %-d, %Y"))
      expect(dashboard).to have_custom_label_text(today.strftime("%b %-d, %Y"))
    end

    it "hand-picking a range applies after clicking Apply", time: Time.utc(2026, 5, 26, 12, 0, 0) do
      dashboard.visit
      dashboard.open_custom_date_range
      dashboard.pick_calendar_day("2026-05-01")
      dashboard.pick_calendar_day("2026-05-20")
      dashboard.apply_custom_range

      expect(dashboard).to have_active_period("custom")
      expect(page).to have_current_path(
        "/admin?end_date=2026-05-20&range=custom&start_date=2026-05-01",
      )
      expect(dashboard).to have_custom_label_text("May 1")
      expect(dashboard).to have_custom_label_text("May 20")
    end

    it "Cancel closes the popover and leaves the active range unchanged",
       time: Time.utc(2026, 5, 26, 12, 0, 0) do
      dashboard.visit
      dashboard.open_custom_date_range
      dashboard.pick_calendar_day("2026-05-01")
      dashboard.cancel_custom_range

      expect(dashboard).to have_no_picker_open
      expect(dashboard).to have_active_period("last_30_days")
    end

    it "Esc closes the popover and leaves the active range unchanged",
       time: Time.utc(2026, 5, 26, 12, 0, 0) do
      dashboard.visit
      dashboard.open_custom_date_range
      dashboard.pick_calendar_day("2026-05-01")
      dashboard.dismiss_picker_via_escape

      expect(dashboard).to have_no_picker_open
      expect(dashboard).to have_active_period("last_30_days")
    end

    it "reopening the popover after dismissal starts in committed state with the active range",
       time: Time.utc(2026, 5, 26, 12, 0, 0) do
      dashboard.visit
      dashboard.open_custom_date_range
      dashboard.pick_calendar_day("2026-05-01")
      dashboard.cancel_custom_range
      dashboard.open_custom_date_range

      # Apply is disabled when no pending selection differs from the active range,
      # which confirms the picker reopened in committed state.
      expect(page).to have_css(".d-date-range-picker__apply[disabled]")
      expect(page).to have_css(".d-date-range-picker__day.--end")
    end

    context "when on mobile", mobile: true do
      it "renders as a bottom sheet and Cancel dismisses without applying",
         time: Time.utc(2026, 5, 26, 12, 0, 0) do
        dashboard.visit
        dashboard.open_custom_date_range

        expect(page).to have_css(".fk-d-menu-modal .d-date-range-picker")

        dashboard.pick_calendar_day("2026-05-01")
        dashboard.cancel_custom_range

        expect(dashboard).to have_no_picker_open
        expect(dashboard).to have_active_period("last_30_days")
      end

      it "applies a sidebar-only preset and closes the bottom sheet" do
        today = Date.today
        start_date = today - 6.months + 1.day

        dashboard.visit
        dashboard.open_custom_date_range
        dashboard.select_sidebar_preset("Last 6 months")

        expect(dashboard).to have_no_picker_open
        expect(dashboard).to have_active_period("custom")
        expect(dashboard).to have_custom_label_text(start_date.strftime("%b %-d, %Y"))
      end
    end
  end
end
