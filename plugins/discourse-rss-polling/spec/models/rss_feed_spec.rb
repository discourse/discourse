# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed do
  fab!(:user)

  describe "#user" do
    it "belongs_to a user" do
      feed = Fabricate(:rss_feed, user: user)
      expect(feed.user).to eq(user)
    end
  end

  describe "#author_username" do
    it "returns the associated user's current username" do
      feed = Fabricate(:rss_feed, user: user)
      expect(feed.author_username).to eq(user.username)
    end

    it "reflects username changes without requiring a feed update" do
      feed = Fabricate(:rss_feed, user: user)
      UsernameChanger.change(user, "shiny_new_name")
      expect(feed.reload.author_username).to eq("shiny_new_name")
    end

    it "returns nil when no user is associated" do
      feed = Fabricate(:rss_feed, user: nil)
      expect(feed.author_username).to be_nil
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
