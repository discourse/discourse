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

  context "with progressive section loading" do
    it "lets staff use fast sections while a nearby section is pending and defers distant work" do
      AdminDashboardSectionConfiguration.update(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
          { id: "search", visible: true },
        ],
        actor: current_user,
      )

      dashboard
        .resize_viewport(height: 600)
        .hold_next_section_request("reports")
        .track_section_requests
        .visit_while_request_pending

      dashboard.wait_for_section_request("highlights").wait_for_section_request("reports")

      expect(dashboard).to have_highlights_content
      expect(dashboard).to have_section_loading("reports")
      expect(dashboard).to have_section_loading("search")
      expect(dashboard.requested_section_ids).not_to include("search")

      dashboard.release_section_requests("reports")

      expect(dashboard).to have_no_section_loading("reports")

      dashboard.scroll_to_section("search").wait_for_section_request("search")

      expect(dashboard).to have_no_section_loading("search")
      expect(dashboard.reports_bulk_request_count).to eq(0)
    end

    it "keeps loaded content stable through date changes and ignores an older response that finishes last",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      AdminDashboardSectionConfiguration.update(
        [
          { id: "traffic", visible: true },
          { id: "highlights", visible: false },
          { id: "reports", visible: false },
          { id: "engagement", visible: false },
          { id: "search", visible: false },
        ],
        actor: current_user,
      )
      Fabricate(:logged_in_browser_application_request, date: "2026-04-20", count: 10)
      Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 20)

      dashboard.visit
      expect(dashboard.site_traffic).to have_headline("30 pageviews in the last 30 days")

      dashboard.hold_next_section_request("traffic").select_preset_while_request_pending(
        "last_7_days",
      )

      expect(dashboard).to have_no_section_loading("traffic")
      expect(dashboard.site_traffic).to have_headline("30 pageviews in the last 30 days")

      dashboard.select_preset_while_request_pending("last_3_months")

      expect(dashboard.site_traffic).to have_headline("30 pageviews in the last 3 months")

      dashboard.release_section_requests("traffic")

      expect(dashboard).to have_active_period("last_3_months")
      expect(dashboard.site_traffic).to have_headline("30 pageviews in the last 3 months")
      expect(dashboard.site_traffic).to have_no_headline("20 pageviews in the last 7 days")
    end

    it "keeps other sections usable when one fails and retries it only when staff ask" do
      AdminDashboardSectionConfiguration.update(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: false },
          { id: "engagement", visible: false },
          { id: "search", visible: false },
        ],
        actor: current_user,
      )

      dashboard.fail_next_section_request("highlights").track_section_requests.visit

      expect(dashboard).to have_section_error("highlights")
      expect(dashboard).to have_no_section_loading("reports")
      expect(dashboard.section_request_count("highlights")).to eq(1)

      dashboard.scroll_to_section("reports").scroll_to_section("highlights")

      expect(dashboard).to have_section_error("highlights")
      expect(dashboard.section_request_count("highlights")).to eq(1)

      dashboard.retry_section("highlights").wait_for_section_request_count("highlights", 2)

      expect(dashboard).to have_no_section_error("highlights")
      expect(dashboard).to have_highlights_content

      dashboard.fail_next_section_request("highlights").select_preset("last_7_days")

      expect(dashboard).to have_section_error("highlights")
      expect(dashboard).to have_highlights_content
      expect(dashboard).to have_no_section_loading("highlights")
      expect(dashboard.section_request_count("highlights")).to eq(3)

      dashboard.retry_section("highlights").wait_for_section_request_count("highlights", 4)

      expect(dashboard).to have_no_section_error("highlights")
      expect(dashboard).to have_highlights_content
    end
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
