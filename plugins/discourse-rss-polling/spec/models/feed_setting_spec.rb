# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseRssPolling::FeedSetting do
  SiteSetting.rss_polling_enabled = true
  let(:feed_url) { "https://blog.discourse.org/feed/" }
  let(:author) { Fabricate(:user, refresh_auto_groups: true) }
  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:feed_category_filter) { "spec" }
  let(:feed_setting) do
    DiscourseRssPolling::FeedSetting.new(
      feed_url: feed_url,
      author_username: author.username,
      discourse_category_id: category.id,
      discourse_tags: [tag.name],
      feed_category_filter: feed_category_filter,
    )
  end
  let(:wrong_feed_setting) do
    DiscourseRssPolling::FeedSetting.new(
      feed_url: feed_url,
      author_username: author.username,
      discourse_category_id: category.id,
      discourse_tags: [tag.name],
      feed_category_filter: "non existing category",
    )
  end
  let(:missing_username_feed_setting) do
    DiscourseRssPolling::FeedSetting.new(
      feed_url: feed_url,
      author_username: nil,
      discourse_category_id: category.id,
      discourse_tags: [tag.name],
      feed_category_filter: feed_category_filter,
    )
  end
  let(:poll_feed_job) { Jobs::DiscourseRssPolling::PollFeed }

  describe "#poll" do
    context "with inline: false" do
      before { Jobs.run_later! }

      it "enqueues a Jobs::DiscourseRssPolling::PollFeed job with the correct arguments" do
        Sidekiq::Testing.fake! do
          expect { feed_setting.poll }.to change(poll_feed_job.jobs, :size).by(1)

          enqueued_job = poll_feed_job.jobs.last

          expect(enqueued_job["args"][0]["feed_url"]).to eq(feed_url)
          expect(enqueued_job["args"][0]["author_username"]).to eq(author.username)
          expect(enqueued_job["args"][0]["discourse_category_id"]).to eq(category.id)
          expect(enqueued_job["args"][0]["discourse_tags"]).to eq([tag.name])
          expect(enqueued_job["args"][0]["feed_category_filter"]).to eq(feed_category_filter)
        end
      end
    end

    context "with inline: true" do
      before { SiteSetting.tagging_enabled = true }

      it "polls and the feed and creates the new topics" do
        Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
        stub_request(:head, feed_url).to_return(status: 200, body: "")
        stub_request(:get, feed_url).to_return(
          status: 200,
          body: file_from_fixtures("feed.rss", "feed"),
        )

        expect { feed_setting.poll(inline: true) }.to change { author.topics.count }

        topic = author.topics.last

        expect(topic.title).to eq("Poll Feed Spec Fixture")
        expect(topic.first_post.raw).to include("<p>This is the body &amp; content. </p>")
        expect(topic.topic_embed.embed_url).to eq(
          "https://blog.discourse.org/2017/09/poll-feed-spec-fixture",
        )
        expect(topic.category).to eq(category)
        expect(topic.tags.first.name).to eq(tag.name)
      end

      it "polls and the feed and does not create the new topics because of the category filter" do
        Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
        stub_request(:head, feed_url).to_return(status: 200, body: "")
        stub_request(:get, feed_url).to_return(
          status: 200,
          body: file_from_fixtures("feed.rss", "feed"),
        )

        expect { wrong_feed_setting.poll(inline: true) }.not_to change { author.topics.count }
      end

      it "does not create the new topics because of the missing username" do
        Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
        stub_request(:head, feed_url).to_return(status: 200, body: "")
        stub_request(:get, feed_url).to_return(
          status: 200,
          body: file_from_fixtures("feed.rss", "feed"),
        )

        expect { missing_username_feed_setting.poll(inline: true) }.not_to change { Topic.count }
      end
    end
  end
end
