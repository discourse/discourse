# frozen_string_literal: true

RSpec.describe SiteController do
  describe "#basic_info" do
    it "is visible always even for sites requiring login" do
      upload = Fabricate(:upload)

      SiteSetting.login_required = true
      SiteSetting.title = "Hammer Time"
      SiteSetting.site_description = "A time for Hammer"
      SiteSetting.logo = upload
      SiteSetting.logo_small = upload
      SiteSetting.apple_touch_icon = upload
      SiteSetting.mobile_logo = upload
      SiteSetting.include_in_discourse_discover = true
      Theme.clear_default!

      get "/site/basic-info.json"
      json = response.parsed_body

      expected_url = UrlHelper.absolute(upload.url)

      expect(json["title"]).to eq("Hammer Time")
      expect(json["description"]).to eq("A time for Hammer")
      expect(json["logo_url"]).to eq(expected_url)
      expect(json["apple_touch_icon_url"]).to eq(expected_url)
      expect(json["logo_small_url"]).to eq(expected_url)
      expect(json["mobile_logo_url"]).to eq(expected_url)
      expect(json["header_primary_color"]).to eq("333333")
      expect(json["header_background_color"]).to eq("ffffff")
      expect(json["login_required"]).to eq(true)
      expect(json["locale"]).to eq("en")
      expect(json["include_in_discourse_discover"]).to eq(true)
    end

    it "includes false values for include_in_discourse_discover and login_required" do
      SiteSetting.include_in_discourse_discover = false
      SiteSetting.login_required = false

      get "/site/basic-info.json"
      json = response.parsed_body

      expect(json["include_in_discourse_discover"]).to eq(false)
      expect(json["login_required"]).to eq(false)
    end
  end

  describe "#statistics" do
    after { DiscoursePluginRegistry.reset! }

    it "is visible for sites requiring login" do
      SiteSetting.login_required = true
      SiteSetting.share_anonymized_statistics = true

      get "/site/statistics.json"
      json = response.parsed_body

      expect(response.status).to eq(200)
      expect(json["topics_count"]).to be_present
      expect(json["posts_count"]).to be_present
      expect(json["users_count"]).to be_present
      expect(json["topics_7_days"]).to be_present
      expect(json["topics_30_days"]).to be_present
      expect(json["posts_7_days"]).to be_present
      expect(json["posts_30_days"]).to be_present
      expect(json["users_7_days"]).to be_present
      expect(json["users_30_days"]).to be_present
      expect(json["active_users_7_days"]).to be_present
      expect(json["active_users_30_days"]).to be_present
      expect(json["likes_count"]).to be_present
      expect(json["likes_7_days"]).to be_present
      expect(json["likes_30_days"]).to be_present
      expect(json["participating_users_7_days"]).to be_present
      expect(json["participating_users_30_days"]).to be_present
    end

    it "is not visible if site setting share_anonymized_statistics is disabled" do
      SiteSetting.share_anonymized_statistics = false

      get "/site/statistics.json"
      expect(response).to redirect_to "/"
    end

    it "returns exposable stats only" do
      Discourse.redis.del(About.stats_cache_key)

      SiteSetting.login_required = true
      SiteSetting.share_anonymized_statistics = true

      plugin = Plugin::Instance.new
      plugin.register_stat("private_stat", expose_via_api: false) do
        { :last_day => 1, "7_days" => 2, "30_days" => 3, :count => 4 }
      end
      plugin.register_stat("exposable_stat", expose_via_api: true) do
        { :last_day => 11, "7_days" => 12, "30_days" => 13, :count => 14 }
      end

      get "/site/statistics.json"
      json = response.parsed_body

      expect(json["exposable_stat_last_day"]).to be(11)
      expect(json["exposable_stat_7_days"]).to be(12)
      expect(json["exposable_stat_30_days"]).to be(13)
      expect(json["exposable_stat_count"]).to be(14)
      expect(json["private_stat_last_day"]).not_to be_present
      expect(json["private_stat_7_days"]).not_to be_present
      expect(json["private_stat_30_days"]).not_to be_present
      expect(json["private_stat_count"]).not_to be_present
    end
  end
end
