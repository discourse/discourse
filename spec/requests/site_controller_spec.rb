require 'rails_helper'

describe SiteController do
  describe '.basic_info' do
    it 'is visible always even for sites requiring login' do
      SiteSetting.login_required = true

      SiteSetting.title = "Hammer Time"
      SiteSetting.site_description = "A time for Hammer"
      SiteSetting.logo_url = "/uploads/logo.png"
      SiteSetting.logo_small_url = "http://boom.com/uploads/logo_small.png"
      SiteSetting.apple_touch_icon_url = "https://boom.com/apple/logo.png"
      SiteSetting.mobile_logo_url = "https://a.a/a.png"

      get "/site/basic-info.json"
      json = JSON.parse(response.body)

      expect(json["title"]).to eq("Hammer Time")
      expect(json["description"]).to eq("A time for Hammer")
      expect(json["logo_url"]).to eq("http://test.localhost/uploads/logo.png")
      expect(json["apple_touch_icon_url"]).to eq("https://boom.com/apple/logo.png")
      expect(json["logo_small_url"]).to eq("http://boom.com/uploads/logo_small.png")
      expect(json["mobile_logo_url"]).to eq("https://a.a/a.png")
    end
  end

  describe '.statistics' do
    it 'is visible for sites requiring login' do
      SiteSetting.login_required = true
      SiteSetting.share_anonymized_statistics = true

      get "/site/statistics.json"
      json = JSON.parse(response.body)

      expect(response.status).to eq(200)
      expect(json["topic_count"]).to be_present
      expect(json["post_count"]).to be_present
      expect(json["user_count"]).to be_present
      expect(json["topics_7_days"]).to be_present
      expect(json["topics_30_days"]).to be_present
      expect(json["posts_7_days"]).to be_present
      expect(json["posts_30_days"]).to be_present
      expect(json["users_7_days"]).to be_present
      expect(json["users_30_days"]).to be_present
      expect(json["active_users_7_days"]).to be_present
      expect(json["active_users_30_days"]).to be_present
      expect(json["like_count"]).to be_present
      expect(json["likes_7_days"]).to be_present
      expect(json["likes_30_days"]).to be_present
    end

    it 'is not visible if site setting share_anonymized_statistics is disabled' do
      SiteSetting.share_anonymized_statistics = false

      get "/site/statistics.json"
      expect(response).to redirect_to '/'
    end
  end
end
