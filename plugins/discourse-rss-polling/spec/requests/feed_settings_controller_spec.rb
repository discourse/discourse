# frozen_string_literal: true

require "rails_helper"

describe DiscourseRssPolling::FeedSettingsController do
  let!(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)

    SiteSetting.rss_polling_enabled = true
  end

  describe "#show" do
    before do
      DiscourseRssPolling::RssFeed.create!(
        url: "https://blog.discourse.org/feed",
        author: "system",
        category_id: 4,
        tags: nil,
        category_filter: "updates",
      )
    end

    it "returns the serialized feed settings" do
      expected_json =
        ActiveModel::ArraySerializer.new(
          DiscourseRssPolling::FeedSettingFinder.all,
          root: :feed_settings,
        ).to_json

      get "/admin/plugins/rss_polling/feed_settings.json"

      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_json)
    end
  end

  describe "#update" do
    it "updates rss feeds" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: "system",
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(200)
      feeds = DiscourseRssPolling::FeedSettingFinder.all
      expect(feeds.count).to eq(1)
    end

    it "allows duplicate rss feed urls" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://blog.discourse.org/feed",
              author_username: "system",
              discourse_category_id: 2,
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(200)

      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://blog.discourse.org/feed",
              author_username: "system",
              discourse_category_id: 4,
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(200)
      feeds = DiscourseRssPolling::FeedSettingFinder.all
      expect(feeds.count).to eq(2)
    end
  end
end
