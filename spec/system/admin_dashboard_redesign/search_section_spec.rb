# frozen_string_literal: true

describe "Admin Dashboard Redesign | Search section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.admin_dashboard_search_section_enabled = true
    sign_in(current_user)
  end

  it "shows staff the search section last among the default sections",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    SeedData::AdminDashboardSections.create

    dashboard.visit
    expect(dashboard).to have_section("search")
    expect(dashboard.section_ids_in_order).to eq(%w[highlights reports traffic engagement search])
  end

  context "with only the search section enabled" do
    before do
      AdminDashboardSectionConfiguration.update(
        [
          { id: "search", visible: true },
          { id: "highlights", visible: false },
          { id: "reports", visible: false },
          { id: "traffic", visible: false },
          { id: "engagement", visible: false },
        ],
        actor: current_user,
      )
    end

    it "lets staff review search health, inspect tooltips, and drill into terms",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate.times(15, :clicked_search_log, term: "ruby", created_at: "2026-05-10 10:00")
      Fabricate.times(10, :search_log, term: "ruby", created_at: "2026-05-10 11:00")
      Fabricate.times(5, :search_log, term: "ruby", created_at: "2026-04-20 10:00")

      Fabricate.times(
        2,
        :clicked_search_log,
        term: "markdown tables",
        created_at: "2026-04-20 11:00",
      )

      Fabricate.times(13, :search_log, term: "markdown tables", created_at: "2026-04-20 12:00")
      Fabricate.times(3, :search_log, term: "markdown tables", created_at: "2026-05-03 10:00")

      Fabricate.times(2, :search_log, term: "discobot", created_at: "2026-05-10 12:00")

      Fabricate.times(20, :clicked_search_log, term: "ruby", created_at: "2026-03-20 10:00")
      Fabricate.times(20, :search_log, term: "ruby", created_at: "2026-03-20 11:00")

      dashboard.visit
      expect(dashboard).to have_section("search")

      search = dashboard.search

      expect(search).to have_headline(
        "Members ran 50 on-site searches in the last 30 days",
        "The no-result rate is climbing compared with the previous period. " \
          "Keep an eye on the content gaps below.",
      )

      expect(search).to have_total_searches("50", delta: { text: "+25%", direction: "pos" })
      expect(search).to have_no_result_rate("4%", delta: { text: "+4%", direction: "neg" })

      search.hover_total_searches_tooltip
      expect(search).to have_total_searches_tooltip(
        "The number of searches performed in your community.",
      )

      search.hover_no_result_rate_tooltip
      expect(search).to have_no_result_rate_tooltip(
        "The percentage of searches where members didn't click any result (0% CTR). " \
          "This indicates that members may be searching for content your community doesn't have.",
      )

      search.hover_trending_tooltip
      expect(search).to have_trending_tooltip("The most popular search terms.")

      expect(search).to have_trending_rows(
        [
          { term: "ruby", searches: 30 },
          { term: "markdown tables", searches: 18 },
          { term: "discobot", searches: 2 },
        ],
      )

      expect(search).to have_content_gap_rows(
        [
          { term: "markdown tables", searches: 18, badge: "Poor match" },
          { term: "discobot", searches: 2, badge: "No match" },
        ],
      )

      search.hover_content_gap_badge("markdown tables")
      expect(search).to have_content_gap_badge_tooltip(
        "Search terms with a click-through rate (CTR) between 1-20%.",
      )

      search.hover_content_gap_badge("discobot")
      expect(search).to have_content_gap_badge_tooltip(
        "Search terms with a 0% click-through rate (CTR).",
      )

      dashboard.select_preset("last_7_days")

      expect(search).to have_headline(
        "Members ran 27 on-site searches in the last 7 days",
        "Members keep finding what they search for, and search volume is steady or growing.",
      )

      expect(search).to have_total_searches("27", delta: { text: "+800%", direction: "pos" })
      expect(search).to have_no_result_rate("7%", delta: { text: "-93%", direction: "pos" })

      search.click_trending_term("ruby")

      expect(page).to have_current_path("/admin/logs/search_logs/term?period=weekly&term=ruby")

      dashboard.visit
      dashboard.select_preset("last_3_months")

      expect(dashboard.search).to have_headline(
        "Members ran 90 on-site searches in the last 3 months",
        "Members keep finding what they search for, and search volume is steady or growing.",
      )

      dashboard.search.click_content_gap_term("discobot")

      expect(page).to have_current_path("/search?q=discobot")
    end

    it "alerts staff when the no-result rate crosses the threshold",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate.times(5, :search_log, term: "ghost", created_at: "2026-05-10 10:00")
      Fabricate.times(5, :clicked_search_log, term: "ruby", created_at: "2026-05-10 11:00")

      dashboard.visit
      search = dashboard.search

      expect(search).to have_headline(
        "Members ran 10 on-site searches in the last 30 days",
        "More than 10% of searches ended without a click this period. " \
          "Review the content gaps below to see what's missing.",
      )
      expect(search).to have_total_searches("10")
      expect(search).to have_alert_no_result_rate("50%")
    end

    it "shows staff a graceful empty state when no searches were logged",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      dashboard.visit
      search = dashboard.search

      expect(search).to have_headline(
        "Not enough search activity to summarise yet.",
        "Pick a longer date range or come back once members have searched more.",
      )
      expect(search).to have_total_searches("0")
      expect(search).to have_no_result_rate("—")
      expect(search).to have_no_kpi_deltas
      expect(search).to have_trending_empty_state("No searches in this period.")
      expect(search).to have_content_gaps_empty_state("No content gaps in this period.")
    end

    it "tells staff when search logging is disabled instead of showing zeros",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      SiteSetting.log_search_queries = false

      dashboard.visit
      search = dashboard.search

      expect(search).to have_logging_disabled_notice(
        "Search logging is disabled, so no search data is being collected. " \
          "Enable log search queries to start collecting it.",
      )
      expect(search).to have_no_kpis
    end

    it "shows staff search activity for a selected custom date range",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(:clicked_search_log, term: "ruby", created_at: "2026-05-02 10:00")
      Fabricate.times(2, :search_log, term: "ruby", created_at: "2026-05-02 11:00")

      Fabricate.times(5, :search_log, term: "ruby", created_at: "2026-04-30 10:00")

      Fabricate(:search_log, term: "solo", created_at: "2026-04-25 10:00")

      dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-03")
      search = dashboard.search

      expect(search).to have_headline(
        "Members ran 3 on-site searches in the selected period",
        "Search volume is down compared with the previous period, " \
          "while most searches still lead to content.",
      )
      expect(search).to have_total_searches("3", delta: { text: "-40%", direction: "neg" })
      expect(search).to have_no_result_rate("0%", delta: { text: "-100%", direction: "pos" })
      expect(search).to have_trending_rows([{ term: "ruby", searches: 3 }])

      dashboard.visit_with_query(range: "custom", start_date: "2026-04-25", end_date: "2026-04-25")

      expect(search).to have_headline(
        "Members ran 1 on-site search in the selected period",
        "More than 10% of searches ended without a click this period. " \
          "Review the content gaps below to see what's missing.",
      )
    end
  end
end
