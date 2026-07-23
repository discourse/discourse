# frozen_string_literal: true

describe "Admin dashboard progressive loading" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(current_user)
  end

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
      .visit

    dashboard.wait_for_section_request("highlights").wait_for_section_request("reports")

    expect(dashboard).to have_highlights_content
    expect(dashboard).to have_section_loading("reports")
    expect(dashboard).to have_section_loading("search")
    expect(dashboard.requested_section_ids).not_to include("search")

    dashboard.release_section_requests("reports")

    expect(dashboard).to have_no_section_loading("reports")

    dashboard.scroll_to_section("search").wait_for_section_request("search")

    expect(dashboard).to have_no_section_loading("search")
  end

  it "shows shaped skeletons for date changes and ignores an older response that finishes last",
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

    dashboard.hold_next_section_request("traffic").select_preset("last_7_days")

    expect(dashboard).to have_section_loading("traffic")
    expect(dashboard.site_traffic).to have_no_headline("30 pageviews in the last 30 days")

    dashboard.select_preset("last_3_months")

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
  end
end
