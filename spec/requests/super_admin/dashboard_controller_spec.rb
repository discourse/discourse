# frozen_string_literal: true

RSpec.describe SuperAdmin::DashboardController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns(reports: [])
    Jobs::CallDiscourseHub.any_instance.stubs(:execute).returns(true)
  end

  def configure_dashboard_sections(visible_ids)
    hidden = AdminDashboardSectionConfiguration::KNOWN_SECTIONS - visible_ids
    ordered =
      visible_ids.map { |id| { id: id, visible: true } } +
        hidden.map { |id| { id: id, visible: false } }
    AdminDashboardSectionConfiguration.update(ordered, actor: Discourse.system_user)
  end

  def populate_new_features(date1 = nil, date2 = nil)
    sample_features = [
      {
        "id" => "1",
        "emoji" => "🤾",
        "title" => "Cool Beans",
        "description" => "Now beans are included",
        "created_at" => date1 || 40.minutes.ago,
      },
      {
        "id" => "2",
        "emoji" => "🙈",
        "title" => "Fancy Legumes",
        "description" => "Legumes too!",
        "created_at" => date2 || 20.minutes.ago,
      },
    ]

    Discourse.redis.set("new_features", MultiJson.dump(sample_features))
  end

  describe "#index" do
    shared_examples "version info present" do
      it "returns discourse version info" do
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["version_check"]).to be_present
      end
    end

    shared_examples "version info absent" do
      before { SiteSetting.version_checks = false }

      it "does not return discourse version info" do
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["version_check"]).not_to be_present
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "when version checking is enabled" do
        before { SiteSetting.version_checks = true }

        include_examples "version info present"
      end

      context "when version checking is disabled" do
        before { SiteSetting.version_checks = false }

        include_examples "version info absent"
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      context "when version checking is enabled" do
        before { SiteSetting.version_checks = true }

        include_examples "version info present"
      end

      context "when version checking is disabled" do
        before { SiteSetting.version_checks = false }

        include_examples "version info absent"
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/dashboard.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when anonymous" do
      it "denies access with a 404 response" do
        get "/admin/dashboard.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    describe "sections payload" do
      before do
        SiteSetting.dashboard_improvements = true
        Discourse.cache.clear
        sign_in(admin)
      end

      let(:section_payloads) do
        response.parsed_body["sections"].index_by { |section| section["id"] }
      end

      context "with highlights_data" do
        let(:highlights_data) { section_payloads["highlights"]&.dig("data") }

        it "returns the highlights payload for the selected dates" do
          Fabricate(:user, created_at: Time.zone.local(2026, 4, 10))
          Fabricate(:user, created_at: Time.zone.local(2026, 4, 15))
          Fabricate(:user, created_at: Time.zone.local(2026, 3, 10))

          get "/admin/dashboard.json", params: { start_date: "2026-04-01", end_date: "2026-04-28" }

          expect(response.status).to eq(200)
          expect(highlights_data).to eq(
            "kpis" => [
              {
                "type" => "new_signups",
                "value" => 2,
                "previous_value" => 1,
                "percent_change" => 100.0,
                "report_type" => "signups",
                "report_query" => {
                  "start_date" => "2026-04-01",
                  "end_date" => "2026-04-28",
                },
              },
              {
                "type" => "dau_mau",
                "value" => nil,
                "previous_value" => nil,
                "percent_change" => nil,
                "report_type" => "dau_by_mau",
                "report_query" => {
                  "start_date" => "2026-04-01",
                  "end_date" => "2026-04-28",
                },
              },
              {
                "type" => "new_contributors",
                "value" => nil,
                "previous_value" => 0,
                "percent_change" => nil,
                "report_type" => "new_contributors",
                "report_query" => {
                  "start_date" => "2026-04-01",
                  "end_date" => "2026-04-28",
                },
              },
            ],
          )
        end
      end

      context "with traffic_data" do
        before { SiteSetting.persist_browser_pageview_events = false }

        let(:traffic_data) { section_payloads["traffic"]&.dig("data") }

        it "returns the site traffic payload for the selected dates" do
          SiteSetting.use_legacy_pageviews = false
          SiteSetting.embed_topics_list = true

          Fabricate(:embeddable_host)
          Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 1)
          Fabricate(:anonymous_browser_application_request, date: "2026-04-29", count: 2)

          Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 10)
          Fabricate(:anonymous_browser_application_request, date: "2026-05-02", count: 20)

          Fabricate(:embedded_application_request, date: "2026-05-02", count: 4)
          Fabricate(:crawler_application_request, date: "2026-05-03", count: 3)

          get "/admin/dashboard.json", params: { start_date: "2026-05-01", end_date: "2026-05-03" }

          expect(traffic_data).to eq(
            "kpis" => {
              "browser_pageviews" => {
                "value" => 30,
                "percent_change" => 900,
                "comparison_period" => {
                  "start_date" => "2026-04-28",
                  "end_date" => "2026-04-30",
                },
              },
              "logged_in_share" => {
                "value" => 33,
              },
            },
            "pageview_series" => [
              {
                "req" => "page_view_logged_in_browser",
                "label" => I18n.t("reports.site_traffic.xaxis.page_view_logged_in_browser"),
                "color" => "#4B3CE0",
                "data" => [
                  { "x" => "2026-05-01", "y" => 10 },
                  { "x" => "2026-05-02", "y" => 0 },
                  { "x" => "2026-05-03", "y" => 0 },
                ],
              },
              {
                "req" => "page_view_anon_browser",
                "label" => I18n.t("reports.site_traffic.xaxis.page_view_anon_browser"),
                "color" => "#9C8DEC",
                "data" => [
                  { "x" => "2026-05-01", "y" => 0 },
                  { "x" => "2026-05-02", "y" => 20 },
                  { "x" => "2026-05-03", "y" => 0 },
                ],
              },
              {
                "req" => "page_view_embed",
                "label" => I18n.t("reports.site_traffic.xaxis.page_view_embed"),
                "color" => "#E6E1F8",
                "data" => [
                  { "x" => "2026-05-01", "y" => 0 },
                  { "x" => "2026-05-02", "y" => 4 },
                  { "x" => "2026-05-03", "y" => 0 },
                ],
              },
              {
                "req" => "page_view_crawler",
                "label" => I18n.t("reports.site_traffic.xaxis.page_view_crawler"),
                "color" => "#D5CDF7",
                "data" => [
                  { "x" => "2026-05-01", "y" => 0 },
                  { "x" => "2026-05-02", "y" => 0 },
                  { "x" => "2026-05-03", "y" => 3 },
                ],
              },
            ],
          )
        end

        it "does not expose admin-only browser pageview cards to moderators" do
          SiteSetting.persist_browser_pageview_events = true
          configure_dashboard_sections(%w[traffic])

          country_code = "US"
          normalized_referrer = "sensitive-referrer.example"
          event_date = Time.zone.local(2026, 5, 2, 12)

          2.times do
            Fabricate(
              :browser_pageview_event,
              country_code: country_code,
              normalized_referrer: normalized_referrer,
              created_at: event_date,
              source: "beacon",
            )
          end

          rollup_range = {
            start_date: Date.iso8601("2026-05-01"),
            end_date: Date.iso8601("2026-05-03"),
          }
          BrowserPageviewCountryDailyRollup.aggregate(**rollup_range)
          BrowserPageviewReferrerDailyRollup.aggregate(**rollup_range)

          get "/admin/dashboard.json", params: { start_date: "2026-05-01", end_date: "2026-05-03" }

          expect(response.status).to eq(200)
          admin_traffic_data =
            response.parsed_body["sections"].find { |section| section["id"] == "traffic" }["data"]
          expect(admin_traffic_data.dig("top_countries", "rows", 0, "country_code")).to eq(
            country_code,
          )
          expect(admin_traffic_data.dig("top_referrers", "rows", 0, "normalized_referrer")).to eq(
            normalized_referrer,
          )

          sign_in(moderator)

          get "/admin/dashboard.json", params: { start_date: "2026-05-01", end_date: "2026-05-03" }

          expect(response.status).to eq(200)
          moderator_traffic_data =
            response.parsed_body["sections"].find { |section| section["id"] == "traffic" }["data"]
          expect(moderator_traffic_data).not_to have_key("top_countries")
          expect(moderator_traffic_data).not_to have_key("top_referrers")
          expect(response.body).not_to include(normalized_referrer)
        end
      end

      context "with search_data" do
        let(:search_data) { section_payloads["search"]&.dig("data") }

        it "returns the search payload for the selected dates" do
          configure_dashboard_sections(%w[search])
          member = Fabricate(:user)
          Fabricate(:clicked_search_log, term: "ruby", user: member, created_at: "2026-05-02 10:00")
          Fabricate(:search_log, term: "ruby", user: member, created_at: "2026-05-02 11:00")

          get "/admin/dashboard.json", params: { start_date: "2026-05-01", end_date: "2026-05-07" }

          expect(response.status).to eq(200)
          expect(search_data).to eq(
            "logging_enabled" => true,
            "headline_state" => "healthy",
            "kpis" => {
              "total_searches" => {
                "value" => 2,
              },
              "no_result_rate" => {
                "value" => 0,
                "exceeds_threshold" => false,
              },
            },
            "trending" => [{ "term" => "ruby", "searches" => 2 }],
            "trending_period" => "weekly",
            "content_gaps" => [],
          )
        end
      end

      it "is omitted when enabled for no one" do
        SiteSetting.dashboard_improvements = false

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_nil
        expect(response.parsed_body["configuration"]).to be_nil
      end

      it "is omitted when enabled for a group the admin is not in" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: "dashboard_improvements", group_ids: group.id.to_s)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_nil
        expect(response.parsed_body["configuration"]).to be_nil
      end

      it "is returned when enabled for the admin's group" do
        group = Fabricate(:group)
        group.add(admin)
        Fabricate(:site_setting_group, name: "dashboard_improvements", group_ids: group.id.to_s)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_present
        expect(response.parsed_body["configuration"]).to be_present
      end

      it "is returned with version=alt when the admin is not included" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: "dashboard_improvements", group_ids: group.id.to_s)

        get "/admin/dashboard.json", params: { version: "alt" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_present
        expect(response.parsed_body["configuration"]).to be_present
      end

      it "is omitted with version=alt when enabled for the admin" do
        get "/admin/dashboard.json", params: { version: "alt" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_nil
        expect(response.parsed_body["configuration"]).to be_nil
      end

      it "falls back to default dates when date params are malformed" do
        get "/admin/dashboard.json", params: { start_date: "garbage", end_date: "also-garbage" }

        expect(response.status).to eq(200)
        expect(section_payloads.keys).to contain_exactly(
          "highlights",
          "reports",
          "traffic",
          "engagement",
          "search",
        )
        expect(section_payloads.dig("highlights", "data")).to be_present
        expect(section_payloads.dig("traffic", "data")).to be_present
      end

      it "returns the sections as an ordered array of {id, data}" do
        configure_dashboard_sections(%w[reports highlights])

        get "/admin/dashboard.json"

        ids = response.parsed_body["sections"].map { |s| s["id"] }
        expect(ids).to eq(%w[reports highlights])
      end

      it "omits hidden sections from the data payload" do
        configure_dashboard_sections(%w[highlights reports])

        get "/admin/dashboard.json"

        ids = response.parsed_body["sections"].map { |s| s["id"] }
        expect(ids).not_to include("traffic", "engagement")
      end

      it "includes built engagement data when the section is enabled" do
        configure_dashboard_sections(%w[highlights engagement])
        get "/admin/dashboard.json"

        engagement = response.parsed_body["sections"].find { |s| s["id"] == "engagement" }
        expect(engagement["data"]).to include("kpis", "headline")
      end

      describe "reports section data" do
        before { AdminDashboardReport.delete_all }

        def reports_data
          response.parsed_body["sections"].find { |s| s["id"] == "reports" }&.dig("data")
        end

        it "returns an empty items list when no rows exist" do
          get "/admin/dashboard.json"

          expect(response.status).to eq(200)
          expect(reports_data["items"]).to eq([])
        end

        it "serializes configured rows resolved via the registered providers" do
          AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

          get "/admin/dashboard.json"

          items = reports_data["items"]
          expect(items.size).to eq(1)
          expect(items.first).to include("source" => "core_report", "identifier" => "signups")
          expect(items.first["title"]).to be_present
        end
      end

      it "denies non-staff users" do
        sign_in(user)

        get "/admin/dashboard.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end

      it "allows moderators and returns the sections payload" do
        sign_in(moderator)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"].map { |section| section["id"] }).to include(
          "highlights",
          "traffic",
        )
      end

      it "omits version_check when enabled for the admin" do
        SiteSetting.version_checks = true
        DiscourseUpdates.expects(:check_version).never

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("version_check")
      end

      it "includes version_check when the admin is not included" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: "dashboard_improvements", group_ids: group.id.to_s)
        SiteSetting.version_checks = true

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to have_key("version_check")
      end
    end

    describe "problems payload" do
      before do
        SiteSetting.dashboard_improvements = true
        Discourse.cache.clear
      end

      fab!(:starttls_problem) do
        Fabricate(:admin_notice, identifier: "starttls_disabled", priority: "high")
      end

      fab!(:host_names_problem) do
        Fabricate(:admin_notice, identifier: "host_names", priority: "low")
      end

      it "returns every active problem check in a top-level problems key for an admin" do
        sign_in(admin)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["problems"]).to match_array(
          [
            {
              "id" => starttls_problem.id,
              "priority" => "high",
              "message" => starttls_problem.message,
              "identifier" => "starttls_disabled",
            },
            {
              "id" => host_names_problem.id,
              "priority" => "low",
              "message" => host_names_problem.message,
              "identifier" => "host_names",
            },
          ],
        )
      end

      it "returns every active problem check in a top-level problems key for a moderator" do
        sign_in(moderator)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["problems"]).to match_array(
          [
            {
              "id" => starttls_problem.id,
              "priority" => "high",
              "message" => starttls_problem.message,
              "identifier" => "starttls_disabled",
            },
            {
              "id" => host_names_problem.id,
              "priority" => "low",
              "message" => host_names_problem.message,
              "identifier" => "host_names",
            },
          ],
        )
      end
    end

    describe "configuration payload" do
      before do
        SiteSetting.dashboard_improvements = true
        Discourse.cache.clear
      end

      it "is included for admins and lists every known section with a visibility flag" do
        configure_dashboard_sections(%w[highlights reports])
        sign_in(admin)

        get "/admin/dashboard.json"

        configuration = response.parsed_body["configuration"]
        expect(configuration).to be_present

        ids = configuration["sections"].map { |s| s["id"] }
        expect(ids).to match_array(%w[highlights reports traffic engagement search])

        visible = configuration["sections"].select { |s| s["visible"] }.map { |s| s["id"] }
        expect(visible).to eq(%w[highlights reports])
      end

      it "is omitted for moderators" do
        sign_in(moderator)

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("configuration")
      end

      it "is omitted when the admin is not included" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: "dashboard_improvements", group_ids: group.id.to_s)
        sign_in(admin)

        get "/admin/dashboard.json"

        expect(response.parsed_body).not_to have_key("configuration")
      end
    end
  end

  describe "#update_configuration" do
    before { SiteSetting.dashboard_improvements = true }

    it "persists the configuration and returns 204 for admins" do
      sign_in(admin)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "reports", visible: true },
              { id: "highlights", visible: true },
              { id: "traffic", visible: false },
              { id: "engagement", visible: false },
              { id: "search", visible: false },
            ],
          }

      expect(response.status).to eq(204)
      expect(AdminDashboardSectionConfiguration.visible_section_ids).to eq(%w[reports highlights])
    end

    it "keeps a section's position when it is toggled off" do
      sign_in(admin)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "highlights", visible: false },
              { id: "reports", visible: true },
              { id: "traffic", visible: true },
              { id: "engagement", visible: true },
            ],
          }

      expect(response.status).to eq(204)
      expect(AdminDashboardSectionConfiguration.sections.first).to eq(
        { id: "highlights", visible: false },
      )
    end

    it "drops unknown section ids silently" do
      sign_in(admin)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [{ id: "frobnitz", visible: true }, { id: "highlights", visible: true }],
          }

      expect(response.status).to eq(204)
      expect(AdminDashboardSectionConfiguration.sections.map { |s| s[:id] }).to match_array(
        %w[highlights reports traffic engagement search],
      )
    end

    it "coerces non-boolean visible values" do
      sign_in(admin)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "highlights", visible: "true" },
              { id: "reports", visible: "false" },
              { id: "engagement", visible: "1" },
              { id: "traffic", visible: "0" },
              { id: "search", visible: "false" },
            ],
          }

      expect(AdminDashboardSectionConfiguration.visible_section_ids).to eq(
        %w[highlights engagement],
      )
    end

    it "returns 404 for moderators" do
      sign_in(moderator)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [{ id: "highlights", visible: true }],
          }

      expect(response.status).to eq(404)
    end

    it "returns 404 for anonymous users" do
      put "/admin/dashboard/configuration.json",
          params: {
            sections: [{ id: "highlights", visible: true }],
          }

      expect(response.status).to eq(404)
    end

    it "reflects the new configuration for moderators on a subsequent GET" do
      sign_in(admin)

      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "highlights", visible: true },
              { id: "reports", visible: false },
              { id: "traffic", visible: false },
              { id: "engagement", visible: false },
              { id: "search", visible: false },
            ],
          }

      sign_in(moderator)

      get "/admin/dashboard.json"

      ids = response.parsed_body["sections"].map { |s| s["id"] }
      expect(ids).to eq(["highlights"])
    end
  end

  describe "#problems" do
    before { ProblemCheck.stubs(:realtime).returns(stub(run_all: [])) }

    context "when logged in as an admin" do
      before { sign_in(admin) }
      context "when there are no problems" do
        it "returns an empty array" do
          post "/admin/dashboard/problems.json"

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["problems"].size).to eq(0)
        end
      end

      context "when there are problems" do
        before do
          Fabricate(:admin_notice, subject: "problem", identifier: "foo")
          Fabricate(:admin_notice, subject: "problem", identifier: "bar")
        end

        it "returns an array of strings" do
          post "/admin/dashboard/problems.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["problems"].size).to eq(2)
        end
      end
    end

    context "when logged in as a moderator" do
      before do
        sign_in(moderator)

        Fabricate(:admin_notice, subject: "problem", identifier: "foo")
        Fabricate(:admin_notice, subject: "problem", identifier: "bar")
      end

      it "returns a list of problems" do
        post "/admin/dashboard/problems.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["problems"].size).to eq(2)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        post "/admin/dashboard/problems.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#new_features" do
    after { DiscourseUpdates.clean_state }

    before { UpcomingChanges.stubs(:permanent_upcoming_changes).returns([]) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "is empty by default" do
        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"]).to eq([])
      end

      it "fails gracefully for invalid JSON" do
        Discourse.redis.set("new_features", "INVALID JSON")
        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"]).to eq([])
      end

      it "includes new features when available" do
        populate_new_features

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["new_features"].length).to eq(2)
        expect(json["new_features"][0]["emoji"]).to eq("🙈")
        expect(json["new_features"][0]["title"]).to eq("Fancy Legumes")
        expect(json["has_unseen_features"]).to eq(true)
      end

      it "allows for forcing a refresh of new features, busting the cache" do
        populate_new_features

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"].length).to eq(2)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"].length).to eq(2)

        DiscourseUpdates.stubs(:new_features_response_json).returns(
          [
            {
              "id" => "3",
              "emoji" => "🚀",
              "title" => "Space platform launched!",
              "description" => "Now to make it to the next planet unscathed...",
              "created_at" => 1.minute.ago,
            },
          ].to_json,
        )

        get "/admin/whats-new.json?force_refresh=true"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"].length).to eq(1)
        expect(json["new_features"][0]["id"]).to eq("3")
      end

      it "passes unseen feature state" do
        populate_new_features
        DiscourseUpdates.mark_new_features_as_seen(admin.id)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["has_unseen_features"]).to eq(false)
      end

      it "sets/bumps the last viewed feature date for the admin" do
        date1 = 30.minutes.ago
        date2 = 20.minutes.ago
        populate_new_features(date1, date2)

        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to eq(nil)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to be_within_one_second_of(
          date2,
        )

        date2 = 10.minutes.ago
        populate_new_features(date1, date2)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to be_within_one_second_of(
          date2,
        )
      end

      it "marks new features as seen" do
        date1 = 30.minutes.ago
        date2 = 20.minutes.ago
        populate_new_features(date1, date2)

        expect(DiscourseUpdates.new_features_last_seen(admin.id)).to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)

        expect(DiscourseUpdates.new_features_last_seen(admin.id)).not_to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)

        expect(DiscourseUpdates.new_features_last_seen(moderator.id)).to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(moderator.id)).to eq(true)
      end

      it "doesn't error when there are no new features" do
        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
      end

      context "when a permanent upcoming change exists and the feed is empty" do
        before do
          UpcomingChanges.unstub(:permanent_upcoming_changes)
          UpcomingChanges.stubs(:permanent_upcoming_changes).returns(
            [
              {
                setting: :enable_upload_debug_mode,
                humanized_name: SiteSetting.humanized_names(:enable_upload_debug_mode),
                description: SiteSetting.description(:enable_upload_debug_mode),
                upcoming_change: {
                  learn_more_url: "https://meta.discourse.org/t/-/1234",
                  image: {
                    url:
                      "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
                  },
                },
              },
            ],
          )
          UpcomingChanges.stubs(:image_exists?).returns(true)
          UpcomingChanges.stubs(:image_data).returns(
            {
              url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
              width: 244,
              height: 66,
              file_path: file_from_fixtures("logo.png", "images").path,
            },
          )
        end

        it "includes the permanent upcoming change in the whats-new payload" do
          freeze_time do
            get "/admin/whats-new.json"
            expect(response.status).to eq(200)
            json = response.parsed_body
            feature =
              json["new_features"].find do |row|
                row["upcoming_change_setting_name"] == "enable_upload_debug_mode"
              end
            expect(feature).to be_present
            expect(feature["title"]).to eq(SiteSetting.humanized_names(:enable_upload_debug_mode))
            expect(feature["description"]).to eq(SiteSetting.description(:enable_upload_debug_mode))
            expect(feature["link"]).to eq("https://meta.discourse.org/t/-/1234")
            expect(feature["screenshot_url"]).to eq(
              "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
            )
            expect(Time.parse(feature["created_at"])).to eq_time(Time.zone.now)
          end
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "includes new features when available" do
        populate_new_features

        get "/admin/whats-new.json"

        json = response.parsed_body

        expect(json["new_features"].length).to eq(2)
        expect(json["new_features"][0]["emoji"]).to eq("🙈")
        expect(json["new_features"][0]["title"]).to eq("Fancy Legumes")
        expect(json["has_unseen_features"]).to eq(true)
      end

      it "doesn't set last viewed feature date for moderators" do
        populate_new_features

        expect(DiscourseUpdates.get_last_viewed_feature_date(moderator.id)).to eq(nil)

        get "/admin/whats-new.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(moderator.id)).to eq(nil)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/whats-new.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#bulk_reports" do
    let(:fake_provider) do
      Class.new(AdminDashboard::Reports::SourceProvider) do
        def self.source_name = "fake_source"
        def self.fetch_many(identifiers, guardian:, filters: {})
          identifiers.each_with_object({}) do |id, h|
            h[id.to_s] = { id: id.to_s, filters: filters }
          end
        end
      end
    end

    let(:plugin) { Plugin::Instance.new }

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
        entry[:value] == fake_provider
      end
    end

    context "when not signed in" do
      it "denies access" do
        post "/admin/dashboard/reports/bulk.json", params: { items: [] }
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as a non-admin" do
      before { sign_in(user) }

      it "denies access" do
        post "/admin/dashboard/reports/bulk.json", params: { items: [] }
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "returns items in the order they were requested" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)

        post "/admin/dashboard/reports/bulk.json",
             params: {
               items: [
                 { source: "fake_source", identifier: "a" },
                 { source: "fake_source", identifier: "b" },
                 { source: "fake_source", identifier: "c" },
               ],
             }

        expect(response.status).to eq(200)
        items = response.parsed_body["items"]
        expect(items.map { |i| i["identifier"] }).to eq(%w[a b c])
        expect(items.map { |i| i["source"] }).to eq(%w[fake_source fake_source fake_source])
      end

      it "returns each requested item's data, keyed by identifier" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)

        post "/admin/dashboard/reports/bulk.json",
             params: {
               items: [
                 { source: "fake_source", identifier: "a" },
                 { source: "fake_source", identifier: "b" },
               ],
             }

        expect(response.status).to eq(200)
        items = response.parsed_body["items"]
        expect(items.map { |i| [i["identifier"], i["data"]["id"]] }).to eq([%w[a a], %w[b b]])
      end

      it "returns data: nil for items whose source has no registered provider" do
        post "/admin/dashboard/reports/bulk.json",
             params: {
               items: [{ source: "totally_unregistered", identifier: "x" }],
             }

        expect(response.status).to eq(200)
        items = response.parsed_body["items"]
        expect(items.size).to eq(1)
        expect(items.first["data"]).to be_nil
        expect(items.first["source"]).to eq("totally_unregistered")
      end

      it "returns data shaped by the dashboard filters" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)

        post "/admin/dashboard/reports/bulk.json",
             params: {
               items: [{ source: "fake_source", identifier: "x" }],
               filters: {
                 start_date: "2026-01-01",
                 end_date: "2026-01-31",
               },
             }

        expect(response.status).to eq(200)
        data = response.parsed_body["items"].first["data"]
        expect(data["filters"]).to include("start_date" => "2026-01-01", "end_date" => "2026-01-31")
      end

      it "rejects requests with more than AdminDashboardReport::VISIBLE_CAP items" do
        items =
          (AdminDashboardReport::VISIBLE_CAP + 1).times.map do |i|
            { source: "x", identifier: i.to_s }
          end
        post "/admin/dashboard/reports/bulk.json", params: { items: items }
        expect(response.status).to eq(400)
      end

      it "rejects items missing source or identifier" do
        post "/admin/dashboard/reports/bulk.json", params: { items: [{ source: "fake_source" }] }
        expect(response.status).to eq(400)
      end

      it "rejects requests with a non-array items field" do
        post "/admin/dashboard/reports/bulk.json", params: { items: "not_an_array" }
        expect(response.status).to eq(400)
      end
    end
  end

  describe "#available_reports" do
    before { AdminDashboardReport.delete_all }

    let(:fake_provider) do
      Class.new(AdminDashboard::Reports::SourceProvider) do
        def self.source_name = "a_fake_source"
        def self.label = "Fake"

        def self.universe
          [%w[banana Banana], %w[date Date], %w[fig Fig]].map do |id, fruit|
            AdminDashboard::Reports::ResolvedReport.new(
              source: source_name,
              identifier: id,
              title: "Zfruit #{fruit}",
              description: "Desc #{id}",
              label: label,
              url: "/fake/#{id}",
            )
          end
        end

        def self.list_all(search: nil, after: nil, limit: nil)
          items = universe
          if search.present?
            items = items.select { |item| item.title.downcase.include?(search.downcase) }
          end
          seek(items, after: after, limit: limit)
        end

        def self.resolve_many(identifiers, guardian:)
          universe
            .select { |item| identifiers.map(&:to_s).include?(item.identifier) }
            .index_by(&:identifier)
        end
      end
    end

    let(:alt_provider) do
      Class.new(AdminDashboard::Reports::SourceProvider) do
        def self.source_name = "b_alt_source"
        def self.label = "Alt"

        def self.universe
          [%w[apple Apple], %w[cherry Cherry], %w[egg Egg]].map do |id, fruit|
            AdminDashboard::Reports::ResolvedReport.new(
              source: source_name,
              identifier: id,
              title: "Zfruit #{fruit}",
              description: nil,
              label: label,
              url: nil,
            )
          end
        end

        def self.list_all(search: nil, after: nil, limit: nil)
          items = universe
          if search.present?
            items = items.select { |item| item.title.downcase.include?(search.downcase) }
          end
          seek(items, after: after, limit: limit)
        end

        def self.resolve_many(_identifiers, guardian:)
          {}
        end
      end
    end

    let(:wide_provider) do
      Class.new(AdminDashboard::Reports::SourceProvider) do
        def self.source_name = "c_wide_source"
        def self.label = "Wide"

        def self.universe
          (1..40).map do |index|
            padded = format("%02d", index)
            AdminDashboard::Reports::ResolvedReport.new(
              source: source_name,
              identifier: "row_#{padded}",
              title: "Widerow #{padded}",
              description: nil,
              label: label,
              url: nil,
            )
          end
        end

        def self.list_all(search: nil, after: nil, limit: nil)
          items = universe
          if search.present?
            items = items.select { |item| item.title.downcase.include?(search.downcase) }
          end
          seek(items, after: after, limit: limit)
        end

        def self.resolve_many(_identifiers, guardian:)
          {}
        end
      end
    end

    let(:plugin) { Plugin::Instance.new }

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
        [fake_provider, alt_provider, wide_provider].include?(entry[:value])
      end
    end

    context "when not signed in" do
      it "denies access" do
        get "/admin/dashboard/reports/available.json"
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as a moderator" do
      before { sign_in(Fabricate(:moderator)) }

      it "denies access" do
        get "/admin/dashboard/reports/available.json"
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "returns enabled, available, and providers" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        AdminDashboardReport.create!(source: "a_fake_source", identifier: "banana", position: 0)

        get "/admin/dashboard/reports/available.json", params: { search: "Zfruit" }
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["providers"].map { |provider| provider["source"] }).to include("a_fake_source")
        fake_summary = body["providers"].find { |provider| provider["source"] == "a_fake_source" }
        expect(fake_summary["label"]).to eq("Fake")

        expect(body["enabled"].map { |item| item["identifier"] }).to eq(["banana"])
        expect(body["enabled"].first["label"]).to eq("Fake")

        fake_available = body["available"].select { |item| item["source"] == "a_fake_source" }
        expect(fake_available.map { |item| item["identifier"] }).to contain_exactly(
          "banana",
          "date",
          "fig",
        )
      end

      it "includes already-enabled identifiers in the available list" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        AdminDashboardReport.create!(source: "a_fake_source", identifier: "banana", position: 0)
        AdminDashboardReport.create!(source: "a_fake_source", identifier: "date", position: 1)

        get "/admin/dashboard/reports/available.json", params: { search: "Zfruit" }
        body = response.parsed_body
        fake_available = body["available"].select { |item| item["source"] == "a_fake_source" }
        expect(fake_available.map { |item| item["identifier"] }).to contain_exactly(
          "banana",
          "date",
          "fig",
        )
      end

      it "interleaves providers alphabetically by title rather than grouping them" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        DiscoursePluginRegistry.register_admin_dashboard_report_source(alt_provider, plugin)

        get "/admin/dashboard/reports/available.json", params: { search: "Zfruit" }
        body = response.parsed_body

        expect(body["available"].map { |item| item["identifier"] }).to eq(
          %w[apple banana cherry date egg fig],
        )
        expect(body["available"].map { |item| item["source"] }).to eq(
          %w[b_alt_source a_fake_source b_alt_source a_fake_source b_alt_source a_fake_source],
        )
      end

      it "paginates 30 items per response and emits a cursor when more exist" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(wide_provider, plugin)

        get "/admin/dashboard/reports/available.json", params: { search: "Widerow" }
        expect(response.status).to eq(200)

        body = response.parsed_body
        wide = body["available"].select { |item| item["source"] == "c_wide_source" }
        expect(wide.size).to eq(AdminDashboard::Reports::Listing::PAGE_SIZE)
        expect(wide.first["identifier"]).to eq("row_01")
        expect(body["has_more"]).to eq(true)
        expect(body["cursor"]).to eq("title" => "Widerow 30", "key" => "c_wide_source:row_30")
      end

      it "returns the next batch when the cursor from a previous response is sent back" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(wide_provider, plugin)

        get "/admin/dashboard/reports/available.json",
            params: {
              search: "Widerow",
              cursor: {
                title: "Widerow 30",
                key: "c_wide_source:row_30",
              },
            }
        body = response.parsed_body
        wide = body["available"].select { |item| item["source"] == "c_wide_source" }

        expect(wide.map { |item| item["identifier"] }).to eq(
          (31..40).map { |number| "row_#{number}" },
        )
        expect(body["has_more"]).to eq(false)
        expect(body["cursor"]).to be_nil
      end

      it "treats a malformed cursor as the first page" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(wide_provider, plugin)

        get "/admin/dashboard/reports/available.json",
            params: {
              search: "Widerow",
              cursor: "garbage",
            }
        body = response.parsed_body

        expect(body["available"].first["identifier"]).to eq("row_01")
        expect(body["has_more"]).to eq(true)
      end

      it "filters by the search param" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)

        get "/admin/dashboard/reports/available.json", params: { search: "Zfruit ba" }
        body = response.parsed_body
        fake_available = body["available"].select { |item| item["source"] == "a_fake_source" }
        expect(fake_available.map { |item| item["identifier"] }).to eq(["banana"])
      end
    end
  end

  describe "#update_reports_section" do
    before { AdminDashboardReport.delete_all }

    let(:fake_provider) do
      Class.new(AdminDashboard::Reports::SourceProvider) do
        def self.source_name = "fake_source"
        def self.label = "Fake"
        def self.accessible_ids(identifiers, guardian:)
          identifiers.map(&:to_s).reject { |id| id == "forbidden" }.to_set
        end
      end
    end

    let(:plugin) { Plugin::Instance.new }

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
        entry[:value] == fake_provider
      end
    end

    context "when not signed in" do
      it "denies access" do
        put "/admin/dashboard/reports/layout.json", params: { items: [] }
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as a moderator" do
      before { sign_in(Fabricate(:moderator)) }

      it "denies access" do
        put "/admin/dashboard/reports/layout.json", params: { items: [] }
        expect(response.status).to eq(404)
      end
    end

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "replaces the current layout with the supplied items in order" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        AdminDashboardReport.create!(source: "fake_source", identifier: "old", position: 0)

        put "/admin/dashboard/reports/layout.json",
            params: {
              items: [
                { source: "fake_source", identifier: "new_a" },
                { source: "fake_source", identifier: "new_b" },
              ],
            }

        expect(response.status).to eq(204)
        rows = AdminDashboardReport.order(:position).pluck(:identifier, :position)
        expect(rows).to eq([["new_a", 0], ["new_b", 1]])
      end

      it "accepts an empty layout (removes everything)" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        AdminDashboardReport.create!(source: "fake_source", identifier: "y", position: 0)

        put "/admin/dashboard/reports/layout.json", params: { items: [] }
        expect(response.status).to eq(204)
        expect(AdminDashboardReport.count).to eq(0)
      end

      it "rejects more than VISIBLE_CAP items" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
        items =
          (AdminDashboardReport::VISIBLE_CAP + 1).times.map do |i|
            { source: "fake_source", identifier: "id#{i}" }
          end
        put "/admin/dashboard/reports/layout.json", params: { items: items }
        expect(response.status).to eq(400)
      end

      it "rejects items missing source or identifier" do
        put "/admin/dashboard/reports/layout.json", params: { items: [{ source: "fake_source" }] }
        expect(response.status).to eq(400)
      end

      it "rejects a non-array items field" do
        put "/admin/dashboard/reports/layout.json", params: { items: "not_an_array" }
        expect(response.status).to eq(400)
      end

      it "rejects items whose source has no registered provider" do
        put "/admin/dashboard/reports/layout.json",
            params: {
              items: [{ source: "totally_unregistered", identifier: "x" }],
            }
        expect(response.status).to eq(400)
      end

      it "rejects items the guardian cannot access" do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)

        put "/admin/dashboard/reports/layout.json",
            params: {
              items: [{ source: "fake_source", identifier: "forbidden" }],
            }

        expect(response.status).to eq(403)
        expect(AdminDashboardReport.count).to eq(0)
      end
    end
  end
end
