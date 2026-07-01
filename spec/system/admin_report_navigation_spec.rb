# frozen_string_literal: true

RSpec.describe "Admin report navigation" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:dashboard_reports) { PageObjects::Pages::AdminDashboardReports.new }
  let(:admin_report) { PageObjects::Pages::AdminReport.new }

  before do
    SiteSetting.dashboard_improvements = true
    AdminDashboardSectionConfiguration.update(
      [
        { id: "reports", visible: true },
        { id: "highlights", visible: false },
        { id: "traffic", visible: false },
        { id: "engagement", visible: false },
      ],
      actor: current_user,
    )
    AdminDashboardReport.delete_all
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
    sign_in(current_user)
  end

  it "lets admins return to the dashboard after viewing a report" do
    admin_report.visit("signups")

    expect(admin_report).to have_back_to_all_reports
    expect(admin_report).to have_no_back_to_dashboard

    admin_report.go_back

    expect(admin_report).to have_current_all_reports_path

    dashboard.visit_with_query(range: "custom", start_date: "2026-01-01", end_date: "2026-01-31")
    dashboard_path = dashboard.current_request_uri
    expect(dashboard_reports).to have_card("core_report:signups")

    dashboard_reports.open_report("core_report:signups")

    expect(admin_report).to have_back_to_dashboard(dashboard_path)
    expect(admin_report).to have_no_back_to_all_reports

    admin_report.go_back

    expect(dashboard).to have_current_dashboard_path(dashboard_path)
  end
end
