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

    it "matches the category filter case-insensitively" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)

      post "/admin/plugins/rss_polling/feed_settings/test.json",
           params: {
             feed_url:,
             feed_category_filter: "SPEC",
           }

      expect(response.parsed_body["items"].first["status"]).to eq("would_import")
    end

    it "flags items that are already imported" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
      TopicEmbed.import(
        Discourse.system_user,
        "https://blog.discourse.org/2017/09/poll-feed-spec-fixture/",
        "Poll Feed Spec Fixture",
        "content",
      )

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      expect(response.parsed_body["items"].first["status"]).to eq("already_imported")
    end
  end

  describe "#category_requirements" do
    it "returns the category's required tag groups with their tags" do
      category = Fabricate(:category)
      tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag, name: "required-tag")])
      CategoryRequiredTagGroup.create!(category:, tag_group:, min_count: 1)

      get "/admin/plugins/rss_polling/feed_settings/category_requirements.json",
          params: {
            category_id: category.id,
          }

      expect(response.status).to eq(200)
      group = response.parsed_body["required_tag_groups"].first
      expect(group["tag_group"]).to eq(tag_group.name)
      expect(group["min_count"]).to eq(1)
      expect(group["tags"]).to eq(["required-tag"])
    end

    it "returns no requirements for a category without required tag groups" do
      category = Fabricate(:category)

      get "/admin/plugins/rss_polling/feed_settings/category_requirements.json",
          params: {
            category_id: category.id,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["required_tag_groups"]).to eq([])
    end
  end

  describe "#history" do
    fab!(:rss_feed) { Fabricate(:rss_feed, url: "https://blog.discourse.org/feed", user: admin) }

    it "returns the feed's recent poll attempts" do
      DiscourseRssPolling::PollAttempt.record!(
        rss_feed_id: rss_feed.id,
        items: [
          { "title" => "An item", "url" => "https://x.test/a", "status" => "imported" },
          { "title" => "Another", "url" => "https://x.test/b", "status" => "imported" },
          { "title" => "Skipped", "url" => "https://x.test/c", "status" => "skipped" },
        ],
      )

      get "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/history.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["feed_url"]).to eq(rss_feed.url)
      expect(body["poll_attempts"].length).to eq(1)
      attempt = body["poll_attempts"].first
      expect(attempt["imported_count"]).to eq(2)
      expect(attempt["skipped_count"]).to eq(1)
      expect(attempt["items"].first["title"]).to eq("An item")
    end

    it "404s for an unknown feed" do
      get "/admin/plugins/rss_polling/feed_settings/0/history.json"

      expect(response.status).to eq(404)
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

    it "rejects a feed whose category has an unsatisfied required tag group" do
      SiteSetting.tagging_enabled = true
      category = Fabricate(:category)
      tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag, name: "needed")])
      CategoryRequiredTagGroup.create!(category:, tag_group:, min_count: 1)

      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: "system",
              discourse_category_id: category.id,
              discourse_tags: [],
            },
          }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].join).to match(/require/i)
      expect(DiscourseRssPolling::RssFeed.count).to eq(0)
    end

    it "allows a feed that satisfies the category's required tag group" do
      SiteSetting.tagging_enabled = true
      category = Fabricate(:category)
      tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag, name: "needed")])
      CategoryRequiredTagGroup.create!(category:, tag_group:, min_count: 1)

      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "https://www.newsite.com/feed",
              author_username: "system",
              discourse_category_id: category.id,
              discourse_tags: ["needed"],
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
