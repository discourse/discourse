# frozen_string_literal: true

RSpec.describe Jobs::DiscourseRssPolling::PollAllFeeds do
  subject(:job) { described_class.new }

  fab!(:user_a) { Fabricate(:user, username: "feed_user_a") }
  fab!(:user_b) { Fabricate(:user, username: "feed_user_b") }

  before { SiteSetting.rss_polling_enabled = true }

  describe "#execute" do
    before do
      Fabricate(:rss_feed, url: "https://www.example.com/feed", user: user_a)
      Fabricate(:rss_feed, url: "https://blog.discourse.org/feed/", user: user_b)

      Jobs.run_later!
      Discourse.redis.del("rss-polling-feeds-polled")
    end

    it "queues a PollFeed job per feed with the right user_id" do
      Sidekiq::Testing.fake! do
        expect { job.execute({}) }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(2)

        enqueued = Jobs::DiscourseRssPolling::PollFeed.jobs.last(2).map { |j| j["args"][0] }

        expect(enqueued).to contain_exactly(
          hash_including("feed_url" => "https://www.example.com/feed", "user_id" => user_a.id),
          hash_including("feed_url" => "https://blog.discourse.org/feed/", "user_id" => user_b.id),
        )
      end
    end

    it "is rate limited" do
      Sidekiq::Testing.fake! do
        expect { job.execute({}) }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(2)
        expect { job.execute({}) }.not_to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }
      end
    end

    context "when the plugin is disabled" do
      before { SiteSetting.rss_polling_enabled = false }

      it "does not queue PollFeed jobs" do
        Sidekiq::Testing.fake! do
          expect { job.execute({}) }.not_to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }
        end
      end
    end
  end
end
