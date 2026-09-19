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
      feed = body["feed_settings"].first
      expect(feed).to include(
        "redacted_feed_url" => "https://blog.discourse.org/feed",
        "discourse_category_id" => 4,
        "feed_category_filter" => "updates",
        "enabled" => true,
      )
      expect(feed).not_to have_key("feed_url")
      expect(feed["author"]).to include(
        "id" => Discourse.system_user.id,
        "username" => Discourse.system_user.username,
      )
    end

    it "serializes the enabled flag for each feed" do
      Fabricate(
        :rss_feed,
        url: "https://disabled.example.com/feed",
        user: Discourse.system_user,
        enabled: false,
      )

      get "/admin/plugins/rss_polling/feed_settings.json"

      feeds = response.parsed_body["feed_settings"].index_by { |feed| feed["redacted_feed_url"] }
      expect(feeds["https://blog.discourse.org/feed"]["enabled"]).to eq(true)
      expect(feeds["https://disabled.example.com/feed"]["enabled"]).to eq(false)
    end

    it "omits the raw credential-bearing feed_url from the list, exposing only the redacted url" do
      Fabricate(
        :rss_feed,
        url: "https://creds.example.com/feed?api_key=secret&api_username=system",
        user: Discourse.system_user,
      )

      get "/admin/plugins/rss_polling/feed_settings.json"

      feed =
        response.parsed_body["feed_settings"].find do |f|
          f["redacted_feed_url"].include?("creds.example.com")
        end
      expect(feed).not_to have_key("feed_url")
      expect(feed["redacted_feed_url"]).not_to include("secret")
      expect(feed["redacted_feed_url"]).not_to include("api_key")
    end

    it "sorts the feeds by URL" do
      Fabricate(:rss_feed, url: "https://aaa.example.com/feed", user: Discourse.system_user)
      Fabricate(:rss_feed, url: "https://zzz.example.com/feed", user: Discourse.system_user)

      get "/admin/plugins/rss_polling/feed_settings.json"

      urls = response.parsed_body["feed_settings"].map { |feed| feed["redacted_feed_url"] }
      expect(urls).to eq(urls.sort)
    end
  end

  describe "#feed" do
    fab!(:rss_feed) do
      Fabricate(
        :rss_feed,
        url: "https://creds.example.com/feed?api_key=secret&api_username=system",
        user: Discourse.system_user,
        category_id: 4,
        category_filter: "updates",
      )
    end

    it "returns the single feed with the raw feed_url for editing" do
      get "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["id"]).to eq(rss_feed.id)
      expect(body["feed_url"]).to eq(
        "https://creds.example.com/feed?api_key=secret&api_username=system",
      )
      expect(body["redacted_feed_url"]).not_to include("secret")
      expect(body["feed_category_filter"]).to eq("updates")
      expect(body["author"]["id"]).to eq(Discourse.system_user.id)
    end

    it "returns 404 for a feed that does not exist" do
      get "/admin/plugins/rss_polling/feed_settings/0.json"

      expect(response.status).to eq(404)
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
      expect(response.parsed_body["error"]).to eq("blank_feed_url")
    end

    it "trims surrounding whitespace from the feed url before fetching" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)

      post "/admin/plugins/rss_polling/feed_settings/test.json",
           params: {
             feed_url: "  #{feed_url}  ",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["items"]).to be_present
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

    it "flags items that are already imported and links to the existing topic" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
      imported_post =
        TopicEmbed.import(
          Discourse.system_user,
          "https://blog.discourse.org/2017/09/poll-feed-spec-fixture/",
          "Poll Feed Spec Fixture",
          "content",
        )

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      item = response.parsed_body["items"].first
      expect(item["status"]).to eq("already_imported")
      expect(item["topic_url"]).to eq(imported_post.topic.relative_url)
    end

    it "returns 422 with an unknown error when building the preview raises unexpectedly" do
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
      DiscourseRssPolling::RssFeed::Action::BuildPreview
        .any_instance
        .stubs(:call)
        .raises(StandardError.new("boom"))

      post "/admin/plugins/rss_polling/feed_settings/test.json", params: { feed_url: }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq("unknown")
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
    it "creates a feed setting and logs a staff action" do
      expect {
        put "/admin/plugins/rss_polling/feed_settings.json",
            params: {
              feed_setting: {
                feed_url: "https://www.newsite.com/feed",
                author_username: "system",
                feed_category_filter: "updates",
              },
            }
      }.to change { UserHistory.where(custom_type: "create_rss_polling_feed").count }.by(1)

      expect(response.status).to eq(200)
      expect(DiscourseRssPolling::RssFeed.count).to eq(1)
      expect(response.parsed_body["id"]).to eq(DiscourseRssPolling::RssFeed.last.id)
    end

    it "logs an update staff action when an existing feed is changed" do
      feed = Fabricate(:rss_feed, url: "https://old.example.com/feed", user: admin)

      expect {
        put "/admin/plugins/rss_polling/feed_settings.json",
            params: {
              feed_setting: {
                id: feed.id,
                feed_url: "https://new.example.com/feed",
                author_username: "system",
              },
            }
      }.to change { UserHistory.where(custom_type: "update_rss_polling_feed").count }.by(1)

      expect(response.status).to eq(200)
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

    it "trims surrounding whitespace from the feed url" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "  https://www.newsite.com/feed  ",
              author_username: "system",
            },
          }

      expect(response.status).to eq(200)
      expect(DiscourseRssPolling::RssFeed.last.url).to eq("https://www.newsite.com/feed")
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

    it "404s when updating a feed that does not exist" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              id: 0,
              feed_url: "https://www.newsite.com/feed",
              author_username: "system",
            },
          }

      expect(response.status).to eq(404)
      expect(DiscourseRssPolling::RssFeed.count).to eq(0)
    end

    it "rejects a feed url that is not http(s)" do
      put "/admin/plugins/rss_polling/feed_settings.json",
          params: {
            feed_setting: {
              feed_url: "javascript:alert(1)",
              author_username: "system",
            },
          }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].join).to match(/http/i)
      expect(DiscourseRssPolling::RssFeed.count).to eq(0)
    end
  end

  describe "#set_enabled" do
    fab!(:rss_feed) { Fabricate(:rss_feed, user: admin) }

    it "disables an enabled feed and logs a staff action" do
      expect {
        put "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/enabled.json",
            params: {
              enabled: false,
            }
      }.to change { UserHistory.where(custom_type: "disable_rss_polling_feed").count }.by(1)

      expect(response.status).to eq(204)
      expect(rss_feed.reload.enabled).to eq(false)
    end

    it "re-enables a disabled feed" do
      rss_feed.update!(enabled: false)

      put "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/enabled.json",
          params: {
            enabled: true,
          }

      expect(response.status).to eq(204)
      expect(rss_feed.reload.enabled).to eq(true)
    end

    it "404s for an unknown feed" do
      put "/admin/plugins/rss_polling/feed_settings/0/enabled.json", params: { enabled: false }

      expect(response.status).to eq(404)
    end

    it "400s when the enabled parameter is missing" do
      put "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/enabled.json", params: {}

      expect(response.status).to eq(400)
      expect(rss_feed.reload.enabled).to eq(true)
    end

    it "400s when the enabled parameter is not a boolean instead of coercing it" do
      put "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/enabled.json",
          params: {
            enabled: "maybe",
          }

      expect(response.status).to eq(400)
      expect(rss_feed.reload.enabled).to eq(true)
    end
  end

  describe "#poll" do
    fab!(:rss_feed) { Fabricate(:rss_feed, user: admin) }

    it "enqueues a forced poll for the feed and logs a staff action" do
      Sidekiq::Testing.fake! do
        expect {
          post "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}/poll.json"
        }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(1).and change {
                UserHistory.where(custom_type: "poll_rss_polling_feed").count
              }.by(1)

        expect(response.status).to eq(204)
        args = Jobs::DiscourseRssPolling::PollFeed.jobs.last["args"][0]
        expect(args).to include("rss_feed_id" => rss_feed.id, "force" => true)
      end
    end

    it "404s for an unknown feed" do
      post "/admin/plugins/rss_polling/feed_settings/0/poll.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    fab!(:rss_feed) { Fabricate(:rss_feed, user: admin) }

    it "destroys the feed, returns 204, and logs a staff action" do
      expect { delete "/admin/plugins/rss_polling/feed_settings/#{rss_feed.id}.json" }.to change {
        DiscourseRssPolling::RssFeed.count
      }.by(-1).and change { UserHistory.where(custom_type: "destroy_rss_polling_feed").count }.by(1)

      expect(response.status).to eq(204)
    end

    it "404s for an unknown feed" do
      delete "/admin/plugins/rss_polling/feed_settings/0.json"

      expect(response.status).to eq(404)
    end
  end
end
