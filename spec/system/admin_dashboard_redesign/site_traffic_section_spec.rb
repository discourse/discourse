# frozen_string_literal: true

describe "Admin Dashboard Redesign | Site Traffic section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.admin_dashboard_sections = "traffic"
    SiteSetting.use_legacy_pageviews = false
    SiteSetting.embed_topics_list = true
    sign_in(current_user)
  end

  it "lets staff review pageview totals, inspect tooltips, and compare another period",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:embeddable_host)

    Fabricate(:logged_in_browser_application_request, date: "2025-11-16", count: 25)
    Fabricate(:logged_in_browser_application_request, date: "2026-03-14", count: 5)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 15)
    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 20)
    Fabricate(:anonymous_browser_application_request, date: "2026-05-12", count: 10)
    Fabricate(:crawler_application_request, date: "2026-05-12", count: 5)
    Fabricate(:embedded_application_request, date: "2026-05-12", count: 3)

    dashboard.visit
    expect(dashboard).to have_section("traffic")

    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("45 pageviews in the last 30 days")
    expect(traffic).to have_trend("up 800%")
    expect(traffic).to have_metric("Logged-in share", "78%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 30 days (Mar 14 – Apr 13, 2026)",
    )

    traffic.hover_logged_in_share_tooltip
    expect(traffic).to have_logged_in_share_tooltip(
      "The share of pageviews from logged-in members.",
    )

    dashboard.select_preset("last_7_days")

    expect(traffic).to have_headline("30 pageviews in the last 7 days")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 7 days (Apr 29 – May 6, 2026)",
    )

    dashboard.select_preset("last_3_months")

    expect(traffic).to have_headline("50 pageviews in the last 3 months")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 3 months (Nov 16, 2025 – Feb 13, 2026)",
    )
  end

  it "shows staff when pageviews are down compared with the previous period",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:logged_in_browser_application_request, date: "2026-03-14", count: 80)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 20)

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("20 pageviews in the last 30 days")
    expect(traffic).to have_down_trend("down 75%")
  end

  it "shows staff traffic for a selected custom date range",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 10)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 20)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-03")
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("20 pageviews in the selected period")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 3 days (Apr 28 – Apr 30, 2026)",
    )
  end

  it "shows staff login-required pageviews without logged-in share",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    SiteSetting.login_required = true

    Fabricate(:embeddable_host)
    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 9)
    Fabricate(:anonymous_browser_application_request, date: "2026-05-12", count: 19)

    Fabricate(:crawler_application_request, date: "2026-05-12", count: 29)
    Fabricate(:embedded_application_request, date: "2026-05-12", count: 5)

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("9 pageviews in the last 30 days")
    expect(traffic).to have_no_metric("Logged-in share")
  end

  it "shows staff a zero-value traffic chart when no pageviews were recorded",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    ApplicationRequest.delete_all

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("0 pageviews in the last 30 days")
    expect(traffic).to have_chart
  end
end
