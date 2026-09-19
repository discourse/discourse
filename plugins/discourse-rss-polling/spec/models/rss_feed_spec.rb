# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed do
  fab!(:user)

  describe "#user" do
    it "belongs_to a user" do
      feed = Fabricate(:rss_feed, user: user)
      expect(feed.user).to eq(user)
    end

    it "falls back to the system user when the author is missing or was deleted" do
      feed = Fabricate(:rss_feed, user: nil)
      expect(feed.user).to eq(Discourse.system_user)
    end
  end

  describe "#enabled" do
    it "defaults to true" do
      feed = Fabricate(:rss_feed, user: user)
      expect(feed.enabled).to eq(true)
    end
  end

  describe ".enabled" do
    it "only returns enabled feeds" do
      enabled_feed = Fabricate(:rss_feed, user: user)
      Fabricate(:rss_feed, user: user, enabled: false)

      expect(described_class.enabled).to contain_exactly(enabled_feed)
    end
  end

  describe "legacy author column" do
    it "is hidden by ignored_columns so the model cannot drift again" do
      expect { described_class.new(author: "anything") }.to raise_error(
        ActiveModel::UnknownAttributeError,
      )
    end
  end

  describe "#poll" do
    fab!(:feed) do
      Fabricate(
        :rss_feed,
        url: "https://example.com/feed",
        user: user,
        category_id: 1,
        tags: "foo,bar",
        category_filter: "updates",
      )
    end

    it "enqueues a PollFeed job with the feed's attributes" do
      Sidekiq::Testing.fake! do
        expect { feed.poll }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(1)

        args = Jobs::DiscourseRssPolling::PollFeed.jobs.last["args"][0]
        expect(args).to include(
          "feed_url" => "https://example.com/feed",
          "user_id" => user.id,
          "discourse_category_id" => 1,
          "discourse_tags" => %w[foo bar],
          "feed_category_filter" => "updates",
        )
      end
    end

    it "executes the PollFeed job inline when inline: true is passed" do
      Jobs::DiscourseRssPolling::PollFeed
        .any_instance
        .expects(:execute)
        .with(has_entries(feed_url: "https://example.com/feed", user_id: user.id))

      feed.poll(inline: true)
    end
  end
end
