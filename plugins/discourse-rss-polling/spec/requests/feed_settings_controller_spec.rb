# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::FeedSettingsController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.rss_polling_enabled = true
  end

  describe "#show" do
    before do
      Fabricate(
        :rss_feed,
        url: "https://blog.discourse.org/feed",
        user: Discourse.system_user,
        category_id: 4,
        tags: nil,
        category_filter: "updates",
      )
    end

    it "returns the serialized feed settings" do
      get "/admin/plugins/rss_polling/feed_settings.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["feed_settings"].length).to eq(1)
      expect(body["feed_settings"].first).to include(
        "feed_url" => "https://blog.discourse.org/feed",
        "user_id" => Discourse.system_user.id,
        "author_username" => Discourse.system_user.username,
        "discourse_category_id" => 4,
        "feed_category_filter" => "updates",
      )
    end
  end

  describe "#update" do
    it "creates a feed setting" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: "system",
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(200)
      expect(DiscourseRssPolling::RssFeed.count).to eq(1)
    end

    it "persists the resolved user_id so renames don't break polling" do
      user = Fabricate(:user, username: "blogauthor")

      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: user.username,
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(200)
      expect(DiscourseRssPolling::RssFeed.last.user_id).to eq(user.id)
    end

    it "returns 422 with a human-readable error when the author_username does not match a user" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: "nope_not_real",
              feed_category_filter: "updates",
            },
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(match(/nope_not_real/))
    end

    it "returns 400 when the contract is invalid" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "",
              author_username: "system",
            },
          }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
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

      expect(DiscourseRssPolling::RssFeed.count).to eq(2)
    end
  end
end
