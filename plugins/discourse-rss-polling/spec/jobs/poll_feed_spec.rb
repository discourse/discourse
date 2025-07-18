# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::DiscourseRssPolling::PollFeed do
  SiteSetting.rss_polling_enabled = true
  let(:feed_url) { "https://blog.discourse.org/feed/" }
  let(:author) { Fabricate(:user, trust_level: 1) }
  let(:raw_feed) { file_from_fixtures("feed.rss", "feed") }
  let(:job) { Jobs::DiscourseRssPolling::PollFeed.new }

  describe "#execute" do
    before do
      Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
      stub_request(:head, feed_url).to_return(status: 200, body: "")
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
    end

    it "creates a topic with the right title, content and author" do
      expect { job.execute(feed_url: feed_url, author_username: author.username) }.to change {
        author.topics.count
      }

      topic = author.topics.last

      expect(topic.title).to eq("Poll Feed Spec Fixture")
      expect(topic.first_post.raw).to include("<p>This is the body &amp; content. </p>")
      expect(topic.topic_embed.embed_url).to eq(
        "https://blog.discourse.org/2017/09/poll-feed-spec-fixture",
      )
    end

    context "with use_pubdate set to false" do
      before do
        SiteSetting.rss_polling_use_pubdate = false
        job.execute(feed_url: feed_url, author_username: author.username)
      end

      it "has a publication date of now" do
        topic = author.topics.last
        expect(topic.created_at.utc).to be_within(1.second).of Time.now
        expect(topic.first_post.created_at.utc).to be_within(1.second).of Time.now
      end
    end

    context "with use_pubdate set to true" do
      before do
        SiteSetting.rss_polling_use_pubdate = true
        job.execute(feed_url: feed_url, author_username: author.username)
      end

      it "has a publication date of the feed" do
        topic = author.topics.last
        expect(topic.created_at).to eq_time(DateTime.parse("2017-09-14 15:22:33.000000000 +0000"))
        expect(topic.first_post.created_at).to eq_time(
          DateTime.parse("2017-09-14 15:22:33.000000000 +0000"),
        )
      end
    end

    context "with a previous poll on a topic with tags" do
      let(:tag1) { Fabricate(:tag, name: "test-from-rss") }
      let(:tag2) { Fabricate(:tag, name: "test-update-from-rss") }

      before do
        SiteSetting.tagging_enabled = true
        job.execute(
          feed_url: feed_url,
          author_username: author.username,
          discourse_tags: [tag1.name],
        )
        Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
      end

      context "with rss polling set to true" do
        before { SiteSetting.rss_polling_update_tags = true }
        it "updates tags by default" do
          topic = author.topics.last
          job.execute(
            feed_url: feed_url,
            author_username: author.username,
            discourse_tags: [tag2.name],
          )
          topic = author.topics.last.reload
          expect(topic.tags).to match_array([tag2])
        end
      end

      context "with rss polling set to false" do
        before { SiteSetting.rss_polling_update_tags = false }

        it "does not update tags" do
          job.execute(
            feed_url: feed_url,
            author_username: author.username,
            discourse_tags: [tag2.name],
          )
          topic = author.topics.last
          expect(topic.tags).to match_array([tag1])
        end
      end
    end

    it "is rate limited by rss_polling_frequency" do
      2.times { job.execute(feed_url: feed_url, author_username: author.username) }

      expect(WebMock).to have_requested(:get, feed_url).once
    end

    it "is not raising error if http request failed" do
      stub_request(:get, feed_url).to_raise(Excon::Error::HTTPStatus)
      job.execute(feed_url: feed_url, author_username: author.username)
    end

    it "skips the topic if the category doesn't exist on our side" do
      invalid_discourse_category_id = 99

      expect {
        job.execute(
          feed_url: feed_url,
          author_username: author.username,
          discourse_category_id: invalid_discourse_category_id,
        )
      }.not_to change { author.topics.count }

      expect(author.topics.last).to be_nil
    end

    it "does not raise error for valid xml but non-rss content" do
      stub_request(:get, feed_url).to_return(status: 200, body: "<html><body>tesing</body></html>")

      expect {
        job.execute(feed_url: feed_url, author_username: author.username)
      }.not_to raise_error
    end

    it "does not raise error for valid xml but non-rss title" do
      stub_request(:get, feed_url).to_return(
        status: 200,
        body: rss_polling_file_fixture("mastodon.rss").read,
      )

      expect {
        job.execute(feed_url: feed_url, author_username: author.username)
      }.not_to raise_error
    end
  end
end
