# frozen_string_literal: true

RSpec.describe Jobs::DiscourseRssPolling::PollAllFeeds do
  subject(:job) { described_class.new }

  fab!(:user_a) { Fabricate(:user, username: "feed_user_a") }
  fab!(:user_b) { Fabricate(:user, username: "feed_user_b") }

  before { SiteSetting.rss_polling_enabled = true }

  describe "#execute" do
    fab!(:feed_a) { Fabricate(:rss_feed, url: "https://www.example.com/feed", user: user_a) }
    fab!(:feed_b) { Fabricate(:rss_feed, url: "https://blog.discourse.org/feed/", user: user_b) }

    before do
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

    context "when a feed is disabled" do
      before { feed_a.update!(enabled: false) }

      it "only queues a PollFeed job for the enabled feeds" do
        Sidekiq::Testing.fake! do
          expect { job.execute({}) }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(
            1,
          )

          enqueued = Jobs::DiscourseRssPolling::PollFeed.jobs.last["args"][0]
          expect(enqueued["feed_url"]).to eq("https://blog.discourse.org/feed/")
        end
      end
    end
  end
end
