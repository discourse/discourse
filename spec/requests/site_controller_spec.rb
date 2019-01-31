require 'rails_helper'

describe SiteController do
  describe '#basic_info' do
    it 'is visible always even for sites requiring login' do
      upload = Fabricate(:upload)

      SiteSetting.login_required = true
      SiteSetting.title = "Hammer Time"
      SiteSetting.site_description = "A time for Hammer"
      SiteSetting.logo = upload
      SiteSetting.logo_small = upload
      SiteSetting.apple_touch_icon = upload
      SiteSetting.mobile_logo = upload
      Theme.clear_default!

      get "/site/basic-info.json"
      json = JSON.parse(response.body)

      expected_url = UrlHelper.absolute(upload.url)

      expect(json["title"]).to eq("Hammer Time")
      expect(json["description"]).to eq("A time for Hammer")
      expect(json["logo_url"]).to eq(expected_url)
      expect(json["apple_touch_icon_url"]).to eq(expected_url)
      expect(json["logo_small_url"]).to eq(expected_url)
      expect(json["mobile_logo_url"]).to eq(expected_url)
      expect(json["header_primary_color"]).to eq("333333")
      expect(json["header_background_color"]).to eq("ffffff")
    end
  end

  describe '#statistics' do
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

  describe '.selectable_avatars' do
    before do
      SiteSetting.selectable_avatars = "https://www.discourse.org\nhttps://meta.discourse.org"
    end

    it 'returns empty array when selectable avatars is disabled' do
      SiteSetting.selectable_avatars_enabled = false

      get "/site/selectable-avatars.json"
      json = JSON.parse(response.body)

      expect(response.status).to eq(200)
      expect(json).to eq([])
    end

    it 'returns an array when selectable avatars is enabled' do
      SiteSetting.selectable_avatars_enabled = true

      get "/site/selectable-avatars.json"
      json = JSON.parse(response.body)

      expect(response.status).to eq(200)
      expect(json).to contain_exactly("https://www.discourse.org", "https://meta.discourse.org")
    end
  end
end
