# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Poll do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:rss_feed)

    let(:params) { { id: rss_feed.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the feed does not exist" do
      let(:params) { { id: -1 } }

      it { is_expected.to fail_to_find_a_model(:rss_feed) }
    end

    context "when the feed exists" do
      it { is_expected.to run_successfully }

      it "enqueues a forced poll job for the feed" do
        Sidekiq::Testing.fake! do
          expect { result }.to change { Jobs::DiscourseRssPolling::PollFeed.jobs.size }.by(1)

          args = Jobs::DiscourseRssPolling::PollFeed.jobs.last["args"].first
          expect(args).to include("rss_feed_id" => rss_feed.id, "force" => true)
        end
      end

      it "logs the poll as a staff action" do
        Sidekiq::Testing.fake! do
          expect { result }.to change { UserHistory.count }.by(1)
          expect(UserHistory.last.custom_type).to eq("poll_rss_polling_feed")
        end
      end
    end
  end
end
