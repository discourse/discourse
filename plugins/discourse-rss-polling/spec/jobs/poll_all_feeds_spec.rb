# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::DiscourseRssPolling::PollAllFeeds do
  SiteSetting.rss_polling_enabled = true
  let(:job) { Jobs::DiscourseRssPolling::PollAllFeeds.new }

  describe "#execute" do
    before do
      DiscourseRssPolling::RssFeed.create!(url: "https://www.example.com/feed", author: "system")
      DiscourseRssPolling::RssFeed.create!(
        url: "https://blog.discourse.org/feed/",
        author: "discourse",
      )

      Jobs.run_later!
      Discourse.redis.del("rss-polling-feeds-polled")
    end

    it "queues correct PollFeed jobs" do
      Sidekiq::Testing.fake! do
        expect { job.execute({}) }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(2)

        enqueued_jobs_args =
          Jobs::DiscourseRssPolling::PollFeed.jobs.last(2).map { |job| job["args"][0] }

        expect(enqueued_jobs_args[0]["feed_url"]).to eq("https://www.example.com/feed")
        expect(enqueued_jobs_args[0]["author_username"]).to eq("system")

        expect(enqueued_jobs_args[1]["feed_url"]).to eq("https://blog.discourse.org/feed/")
        expect(enqueued_jobs_args[1]["author_username"]).to eq("discourse")
      end
    end

    it "is rate limited" do
      Sidekiq::Testing.fake! do
        expect { job.execute({}) }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(2)
        expect { job.execute({}) }.to_not change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }
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
