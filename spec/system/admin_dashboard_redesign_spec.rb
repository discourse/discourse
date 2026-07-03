# frozen_string_literal: true

describe "Admin Dashboard Redesign" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:dashboard_reports) { PageObjects::Pages::AdminDashboardReports.new }
  let(:admin_report) { PageObjects::Pages::AdminReport.new }

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(current_user)
  end

  it "allows a user to use a preset range or select a custom range",
     time: Time.utc(2026, 5, 26, 12, 0, 0) do
    dashboard.visit
    expect(dashboard).to have_active_period("last_30_days")

    dashboard.select_preset("last_7_days")

    expect(page).to have_current_path("/admin?range=last_7_days")
    expect(dashboard).to have_active_period("last_7_days")

    picker = dashboard.open_custom_date_range
    picker.pick_day("2026-05-01")
    picker.pick_day("2026-05-20")
    picker.apply

    expect(dashboard).to have_active_period("custom")
    expect(page).to have_current_path(
      "/admin?end_date=2026-05-20&range=custom&start_date=2026-05-01",
    )
    expect(dashboard).to have_custom_label("May 1, 2026 – May 20, 2026")

    dashboard.select_preset("last_6_months")

    expect(page).to have_current_path("/admin?range=last_6_months")
    expect(dashboard).to have_active_period("last_6_months")
  end

  it "lets admins return to the dashboard after viewing a report" do
    admin_report.visit_default_dashboard_report

    expect(admin_report).to have_back_to_all_reports
    expect(admin_report).to have_no_back_to_dashboard

    admin_report.go_back

    expect(admin_report).to have_current_all_reports_path

    dashboard.visit_with_custom_range(from: "2026-01-01", to: "2026-01-31")
    expect(dashboard_reports).to have_default_report

    dashboard_reports.open_default_report

    expect(admin_report).to have_back_to_dashboard
    expect(admin_report).to have_no_back_to_all_reports

    admin_report.go_back

    expect(dashboard).to have_custom_range(from: "2026-01-01", to: "2026-01-31")
  end
end
