# frozen_string_literal: true

require "seed_data/admin_dashboard_reports"
require "seed_data/admin_dashboard_sections"

RSpec.describe "Admin report navigation" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:dashboard_reports) { PageObjects::Pages::AdminDashboardReports.new }
  let(:admin_report) { PageObjects::Pages::AdminReport.new }
  let(:report_type) { SeedData::AdminDashboardReports::DEFAULT_BUILTIN_REPORTS.first }
  let(:dashboard_report_identifier) do
    "#{AdminDashboard::Reports::CoreReportProvider::SOURCE_NAME}:#{report_type}"
  end

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.admin_dashboard_reports_seeded = false
    SeedData::AdminDashboardSections.create
    SeedData::AdminDashboardReports.create
    sign_in(current_user)
  end

  it "lets admins return to the dashboard after viewing a report" do
    admin_report.visit(report_type)

    expect(admin_report).to have_back_to_all_reports
    expect(admin_report).to have_no_back_to_dashboard

    admin_report.go_back

    expect(admin_report).to have_current_all_reports_path

    dashboard.visit_with_query(range: "custom", start_date: "2026-01-01", end_date: "2026-01-31")
    dashboard_path = dashboard.current_request_uri
    expect(dashboard_reports).to have_card(dashboard_report_identifier)

    dashboard_reports.open_report(dashboard_report_identifier)

    expect(admin_report).to have_back_to_dashboard(dashboard_path)
    expect(admin_report).to have_no_back_to_all_reports

    admin_report.go_back

    expect(dashboard).to have_current_dashboard_path(dashboard_path)
  end
end
