# frozen_string_literal: true

RSpec.describe Admin::DashboardController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    before do
      SiteSetting.dashboard_improvements = true
      sign_in(admin)
    end

    it "returns the ordered section layout without loading core or plugin section data" do
      plugin_loader_calls = 0
      plugin = Plugin::Instance.new
      plugin.register_admin_dashboard_section(id: "support") do
        plugin_loader_calls += 1
        { status: "available" }
      end
      AdminDashboardSectionConfiguration.update(
        [
          { id: "reports", visible: true },
          { id: "support", visible: true },
          { id: "highlights", visible: true },
          { id: "traffic", visible: false },
          { id: "engagement", visible: false },
          { id: "search", visible: false },
        ],
        actor: admin,
      )

      get "/admin/dashboard.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["sections"]).to eq(
        [{ "id" => "reports" }, { "id" => "support" }, { "id" => "highlights" }],
      )
      expect(response.parsed_body["configuration"]["sections"]).to eq(
        [
          { "id" => "reports", "visible" => true },
          { "id" => "support", "visible" => true },
          { "id" => "highlights", "visible" => true },
          { "id" => "traffic", "visible" => false },
          { "id" => "engagement", "visible" => false },
          { "id" => "search", "visible" => false },
        ],
      )
      expect(response.parsed_body).to have_key("problems")
      expect(plugin_loader_calls).to eq(0)
    ensure
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "support"
      end
    end
  end

  describe "#section" do
    before { SiteSetting.dashboard_improvements = true }

    it "returns one core section for the requested date range" do
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 10))
      Fabricate(:user, created_at: Time.zone.local(2026, 3, 10))
      sign_in(admin)

      get "/admin/dashboard/sections/highlights.json",
          params: {
            start_date: "2026-04-01",
            end_date: "2026-04-28",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to match(
        "id" => "highlights",
        "data" =>
          a_hash_including(
            "kpis" =>
              include(
                a_hash_including(
                  "type" => "new_signups",
                  "value" => 1,
                  "report_query" => {
                    "start_date" => "2026-04-01",
                    "end_date" => "2026-04-28",
                  },
                ),
              ),
          ),
      )
    end

    it "returns a registered plugin section through the same staff endpoint" do
      plugin = Plugin::Instance.new
      plugin.register_admin_dashboard_section(
        id: "support",
      ) do |start_date:, end_date:, current_user:|
        { start_date:, end_date:, username: current_user.username }
      end
      sign_in(moderator)

      get "/admin/dashboard/sections/support.json",
          params: {
            start_date: "2026-05-01",
            end_date: "2026-05-07",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "id" => "support",
        "data" => {
          "start_date" => "2026-05-01",
          "end_date" => "2026-05-07",
          "username" => moderator.username,
        },
      )
    ensure
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "support"
      end
    end

    it "preserves moderator redaction for role-sensitive core section data" do
      SiteSetting.persist_browser_pageview_events = true
      normalized_referrer = "sensitive-referrer.example"
      event_date = Time.zone.local(2026, 5, 2, 12)
      Fabricate(
        :browser_pageview_event,
        country_code: "US",
        normalized_referrer:,
        created_at: event_date,
        source: "beacon",
      )
      rollup_range = {
        start_date: Date.iso8601("2026-05-01"),
        end_date: Date.iso8601("2026-05-03"),
      }
      BrowserPageviewCountryDailyRollup.aggregate(**rollup_range)
      BrowserPageviewReferrerDailyRollup.aggregate(**rollup_range)
      sign_in(moderator)

      get "/admin/dashboard/sections/traffic.json",
          params: {
            start_date: "2026-05-01",
            end_date: "2026-05-03",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("data", "kpis")).to be_present
      expect(response.parsed_body["data"]).not_to have_key("top_countries")
      expect(response.parsed_body["data"]).not_to have_key("top_referrers")
      expect(response.body).not_to include(normalized_referrer)
    end

    it "returns an isolated error response when a section loader fails" do
      plugin = Plugin::Instance.new
      plugin.register_admin_dashboard_section(id: "failing_support") do
        raise StandardError, "private failure detail"
      end
      sign_in(admin)

      get "/admin/dashboard/sections/failing_support.json"

      expect(response.status).to eq(500)
      expect(response.parsed_body).to eq("id" => "failing_support", "error" => true)
      expect(response.body).not_to include("private failure detail")
    ensure
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "failing_support"
      end
    end

    it "returns 404 for unknown, hidden, and disabled plugin sections" do
      plugin = Plugin::Instance.new
      plugin.register_admin_dashboard_section(id: "disabled_support", enabled: -> { false }) do
        { status: "unavailable" }
      end
      AdminDashboardSectionConfiguration.update(
        [{ id: "reports", visible: true }, { id: "highlights", visible: false }],
        actor: admin,
      )
      sign_in(admin)

      %w[unknown highlights disabled_support].each do |section_id|
        get "/admin/dashboard/sections/#{section_id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    ensure
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "disabled_support"
      end
    end

    it "supports the alternate redesigned-dashboard preview and rejects unavailable versions" do
      SiteSetting.dashboard_improvements = false
      sign_in(admin)

      get "/admin/dashboard/sections/highlights.json", params: { version: "alt" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq("highlights")

      get "/admin/dashboard/sections/highlights.json"

      expect(response.status).to eq(404)
      expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
    end

    it "denies section data to non-staff users" do
      sign_in(user)

      get "/admin/dashboard/sections/highlights.json"

      expect(response.status).to eq(404)
      expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
    end
  end
end
