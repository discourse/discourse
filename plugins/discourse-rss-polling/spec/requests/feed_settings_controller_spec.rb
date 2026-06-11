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

    it "sorts the feeds by URL" do
      Fabricate(:rss_feed, url: "https://aaa.example.com/feed", user: Discourse.system_user)
      Fabricate(:rss_feed, url: "https://zzz.example.com/feed", user: Discourse.system_user)

      get "/admin/plugins/rss_polling/feed_settings.json"

      urls = response.parsed_body["feed_settings"].map { |feed| feed["feed_url"] }
      expect(urls).to eq(urls.sort)
    end
  end

  describe "#test" do
    let(:feed_url) { "https://blog.discourse.org/feed/" }
    let(:raw_feed) { file_from_fixtures("feed.rss", "feed") }

    it "reports which items would be imported" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["items"]).to be_present
      expect(body["items"].first["status"]).to eq("would_import")
      expect(body["total"]).to eq(body["items"].length)
    end

    it "reports items skipped by the category filter with a reason" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)

      post "/admin/plugins/rss_polling/feed_settings/test.json",
           params: {
             feed_url:,
             feed_category_filter: "does-not-match",
           }

      body = response.parsed_body
      expect(body["items"].map { |item| item["status"] }).to all(eq("skipped"))
      expect(body["items"].first["reason"]).to eq("category_filter_mismatch")
    end

    it "returns an error when the feed cannot be fetched" do
      stub_request(:get, feed_url).to_return(status: 500)

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq("fetch_failed")
    end

    it "requires a feed_url" do
      post "/admin/plugins/rss_polling/feed_settings/test.json", params: {}

      expect(response.status).to eq(400)
    end

    it "handles Atom feeds (term-style categories, <updated>-only dates)" do
      atom = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Atom feed</title>
          <entry>
            <title>An atom entry</title>
            <link href="https://example.com/atom-entry" rel="alternate" type="text/html"/>
            <id>https://example.com/atom-entry</id>
            <updated>2025-05-07T17:46:43Z</updated>
            <content type="html">Body content</content>
            <category term="ai"/>
            <category term="llms"/>
          </entry>
        </feed>
      XML
      stub_request(:get, feed_url).to_return(status: 200, body: atom)

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      expect(response.status).to eq(200)
      item = response.parsed_body["items"].first
      expect(item["categories"]).to eq(%w[ai llms])
      expect(item["published_at"]).to be_present
      expect(item["status"]).to eq("would_import")
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
