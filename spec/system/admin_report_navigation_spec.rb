# frozen_string_literal: true

RSpec.describe "Admin report navigation" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:dashboard_reports) { PageObjects::Pages::AdminDashboardReports.new }
  let(:admin_report) { PageObjects::Pages::AdminReport.new }

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(current_user)
  end

  it "lets admins return to the dashboard after viewing a report" do
    admin_report.visit_default_dashboard_report

    expect(admin_report).to have_back_to_all_reports
    expect(admin_report).to have_no_back_to_dashboard

    admin_report.go_back

    expect(admin_report).to have_current_all_reports_path

    dashboard.visit_with_custom_range(from: "2026-01-01", to: "2026-01-31")
    dashboard.remember_current_location
    expect(dashboard_reports).to have_default_report

    dashboard_reports.open_default_report

    expect(admin_report).to have_back_to_dashboard(dashboard)
    expect(admin_report).to have_no_back_to_all_reports

    admin_report.go_back

    expect(dashboard).to have_returned_to_remembered_location
  end
end
