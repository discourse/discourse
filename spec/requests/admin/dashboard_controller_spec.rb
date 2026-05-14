# frozen_string_literal: true

RSpec.describe Admin::DashboardController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns(reports: [])
    Jobs::CallDiscourseHub.any_instance.stubs(:execute).returns(true)
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

    describe "sections payload" do
      before do
        SiteSetting.dashboard_improvements = true
        SiteSetting.admin_dashboard_sections = "highlights|reports|traffic|engagement"
        Discourse.cache.clear
        sign_in(admin)
      end

      def highlights_data
        sections = response.parsed_body["sections"]
        sections.find { |s| s["id"] == "highlights" }&.dig("data")
      end

      it "is omitted when dashboard_improvements is disabled" do
        SiteSetting.dashboard_improvements = false
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["sections"]).to be_nil
        expect(response.parsed_body["configuration"]).to be_nil
      end

      it "includes a highlights section with kpis" do
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(highlights_data["kpis"]).to be_an(Array)
      end

      it "returns the sections as an ordered array of {id, data}" do
        SiteSetting.admin_dashboard_sections = "reports|highlights"
        get "/admin/dashboard.json"

        ids = response.parsed_body["sections"].map { |s| s["id"] }
        expect(ids).to eq(%w[reports highlights])
      end

      it "omits hidden sections from the data payload" do
        SiteSetting.admin_dashboard_sections = "highlights|reports"
        get "/admin/dashboard.json"

        ids = response.parsed_body["sections"].map { |s| s["id"] }
        expect(ids).not_to include("traffic", "engagement")
      end

      it "leaves data null for sections without a builder yet" do
        SiteSetting.admin_dashboard_sections = "highlights|reports"
        get "/admin/dashboard.json"

        reports = response.parsed_body["sections"].find { |s| s["id"] == "reports" }
        expect(reports["data"]).to be_nil
      end

      it "returns the documented payload shape for new_signups" do
        freeze_time(Time.utc(2026, 4, 28, 12, 0, 0)) do
          Fabricate(:user, created_at: 5.days.ago)
          get "/admin/dashboard.json", params: { start_date: "2026-03-01", end_date: "2026-04-28" }

          kpis = highlights_data["kpis"]
          signups = kpis.find { |k| k["type"] == "new_signups" }

          expect(signups).to include(
            "type" => "new_signups",
            "report_type" => "signups",
            "report_query" => {
              "start_date" => "2026-03-01",
              "end_date" => "2026-04-28",
            },
          )
          expect(signups["value"]).to be >= 1
          expect(signups).to have_key("previous_value")
          expect(signups).to have_key("percent_change")
        end
      end

      it "honours start_date and end_date query params" do
        Fabricate(:user, created_at: 2.days.ago)
        get "/admin/dashboard.json",
            params: {
              start_date: 7.days.ago.strftime("%Y-%m-%d"),
              end_date: Date.current.strftime("%Y-%m-%d"),
            }

        expect(response.status).to eq(200)
        expect(highlights_data["kpis"]).to be_an(Array)
      end

      it "ignores malformed date params and falls back to defaults" do
        get "/admin/dashboard.json", params: { start_date: "garbage", end_date: "also-garbage" }

        expect(response.status).to eq(200)
        expect(highlights_data).to be_present
      end

      it "denies non-staff users" do
        sign_in(user)
        get "/admin/dashboard.json"

        expect(response.status).to eq(404)
      end

      it "allows moderators and returns the sections payload" do
        sign_in(moderator)
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(highlights_data).to be_present
      end

      it "omits version_check when the flag is on" do
        SiteSetting.version_checks = true
        DiscourseUpdates.expects(:check_version).never

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("version_check")
      end

      it "still includes version_check when the flag is off" do
        SiteSetting.dashboard_improvements = false
        SiteSetting.version_checks = true

        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to have_key("version_check")
      end
    end

    describe "configuration payload" do
      before do
        SiteSetting.dashboard_improvements = true
        Discourse.cache.clear
      end

      it "is included for admins and lists every known section with a visibility flag" do
        SiteSetting.admin_dashboard_sections = "highlights|reports"
        sign_in(admin)
        get "/admin/dashboard.json"

        configuration = response.parsed_body["configuration"]
        expect(configuration).to be_present
        ids = configuration["sections"].map { |s| s["id"] }
        expect(ids).to match_array(%w[highlights reports traffic engagement])
        visible = configuration["sections"].select { |s| s["visible"] }.map { |s| s["id"] }
        expect(visible).to eq(%w[highlights reports])
      end

      it "is omitted for moderators" do
        sign_in(moderator)
        get "/admin/dashboard.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("configuration")
      end

      it "is omitted when dashboard_improvements is disabled" do
        SiteSetting.dashboard_improvements = false
        sign_in(admin)
        get "/admin/dashboard.json"

        expect(response.parsed_body).not_to have_key("configuration")
      end
    end
  end

  describe "#update_configuration" do
    before do
      SiteSetting.dashboard_improvements = true
      SiteSetting.admin_dashboard_sections = "highlights|reports|traffic|engagement"
    end

    it "returns 204 and writes the site setting for admins" do
      sign_in(admin)
      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "reports", visible: true },
              { id: "highlights", visible: true },
              { id: "traffic", visible: false },
            ],
          }

      expect(response.status).to eq(204)
      expect(SiteSetting.admin_dashboard_sections).to eq("reports|highlights")
    end

    it "drops unknown section ids silently" do
      sign_in(admin)
      put "/admin/dashboard/configuration.json",
          params: {
            sections: [{ id: "frobnitz", visible: true }, { id: "highlights", visible: true }],
          }

      expect(response.status).to eq(204)
      expect(SiteSetting.admin_dashboard_sections).to eq("highlights")
    end

    it "coerces non-boolean visible values" do
      sign_in(admin)
      put "/admin/dashboard/configuration.json",
          params: {
            sections: [
              { id: "highlights", visible: "true" },
              { id: "reports", visible: "false" },
              { id: "engagement", visible: "1" },
            ],
          }

      expect(SiteSetting.admin_dashboard_sections).to eq("highlights|engagement")
    end

    it "treats an empty sections array as hide-everything" do
      sign_in(admin)
      put "/admin/dashboard/configuration.json", params: { sections: [] }

      expect(response.status).to eq(204)
      expect(SiteSetting.admin_dashboard_sections).to eq("")
    end

    it "treats a missing sections key the same as an empty array" do
      sign_in(admin)
      put "/admin/dashboard/configuration.json"

      expect(response.status).to eq(204)
      expect(SiteSetting.admin_dashboard_sections).to eq("")
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
            sections: [{ id: "highlights", visible: true }],
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
end
