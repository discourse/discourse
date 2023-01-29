# frozen_string_literal: true

RSpec.describe Admin::DashboardController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns(reports: [])
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
  end

  def populate_new_features(date1 = nil, date2 = nil)
    sample_features = [
      {
        "id" => "1",
        "emoji" => "🤾",
        "title" => "Cool Beans",
        "description" => "Now beans are included",
        "created_at" => date1 || (Time.zone.now - 40.minutes),
      },
      {
        "id" => "2",
        "emoji" => "🙈",
        "title" => "Fancy Legumes",
        "description" => "Legumes too!",
        "created_at" => date2 || (Time.zone.now - 20.minutes),
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
  end

  describe "#problems" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "when there are no problems" do
        before { AdminDashboardData.stubs(:fetch_problems).returns([]) }

        it "returns an empty array" do
          get "/admin/dashboard/problems.json"

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["problems"].size).to eq(0)
        end
      end

      context "when there are problems" do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns(["Not enough awesome", "Too much sass"])
        end

        it "returns an array of strings" do
          get "/admin/dashboard/problems.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["problems"].size).to eq(2)
          expect(json["problems"][0]).to be_a(String)
          expect(json["problems"][1]).to be_a(String)
        end
      end
    end

    context "when logged in as a moderator" do
      before do
        sign_in(moderator)
        AdminDashboardData.stubs(:fetch_problems).returns(["Not enough awesome", "Too much sass"])
      end

      it "returns a list of problems" do
        get "/admin/dashboard/problems.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["problems"].size).to eq(2)
        expect(json["problems"]).to contain_exactly("Not enough awesome", "Too much sass")
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/dashboard/problems.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#new_features" do
    after { DiscourseUpdates.clean_state }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "is empty by default" do
        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"]).to eq(nil)
      end

      it "fails gracefully for invalid JSON" do
        Discourse.redis.set("new_features", "INVALID JSON")
        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["new_features"]).to eq(nil)
      end

      it "includes new features when available" do
        populate_new_features

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["new_features"].length).to eq(2)
        expect(json["new_features"][0]["emoji"]).to eq("🙈")
        expect(json["new_features"][0]["title"]).to eq("Fancy Legumes")
        expect(json["has_unseen_features"]).to eq(true)
      end

      it "passes unseen feature state" do
        populate_new_features
        DiscourseUpdates.mark_new_features_as_seen(admin.id)

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["has_unseen_features"]).to eq(false)
      end

      it "sets/bumps the last viewed feature date for the admin" do
        date1 = 30.minutes.ago
        date2 = 20.minutes.ago
        populate_new_features(date1, date2)

        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to eq(nil)

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to be_within_one_second_of(
          date2,
        )

        date2 = 10.minutes.ago
        populate_new_features(date1, date2)

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(admin.id)).to be_within_one_second_of(
          date2,
        )
      end

      it "doesn't error when there are no new features" do
        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "includes new features when available" do
        populate_new_features

        get "/admin/dashboard/new-features.json"

        json = response.parsed_body

        expect(json["new_features"].length).to eq(2)
        expect(json["new_features"][0]["emoji"]).to eq("🙈")
        expect(json["new_features"][0]["title"]).to eq("Fancy Legumes")
        expect(json["has_unseen_features"]).to eq(true)
      end

      it "doesn't set last viewed feature date for moderators" do
        populate_new_features

        expect(DiscourseUpdates.get_last_viewed_feature_date(moderator.id)).to eq(nil)

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        expect(DiscourseUpdates.get_last_viewed_feature_date(moderator.id)).to eq(nil)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/dashboard/new-features.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#mark_new_features_as_seen" do
    after { DiscourseUpdates.clean_state }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "resets last seen for a given user" do
        populate_new_features
        put "/admin/dashboard/mark-new-features-as-seen.json"

        expect(response.status).to eq(200)
        expect(DiscourseUpdates.new_features_last_seen(admin.id)).not_to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "resets last seen for moderator" do
        populate_new_features

        put "/admin/dashboard/mark-new-features-as-seen.json"

        expect(response.status).to eq(200)
        expect(DiscourseUpdates.new_features_last_seen(moderator.id)).not_to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(moderator.id)).to eq(false)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents marking new feature as seen with a 404 response" do
        put "/admin/dashboard/mark-new-features-as-seen.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
