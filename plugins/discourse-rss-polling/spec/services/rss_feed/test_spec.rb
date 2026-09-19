# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Test do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:feed_url) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:feed_url) { "https://blog.discourse.org/feed/" }
    let(:raw_feed) { file_from_fixtures("feed.rss", "feed") }
    let(:params) { { feed_url:, feed_category_filter: nil } }
    let(:dependencies) { {} }

    context "when the contract is invalid" do
      let(:feed_url) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the feed cannot be fetched" do
      before { stub_request(:get, feed_url).to_return(status: 500) }

      it { is_expected.to fail_a_step(:fetch) }

      it "exposes the fetch error and does not build a preview" do
        expect(result[:fetched]).to be_nil
        expect(result[:preview]).to be_nil
        expect(result["result.step.fetch"].error).to eq(:fetch_failed)
      end
    end

    context "when the feed is fetched successfully" do
      before { stub_request(:get, feed_url).to_return(status: 200, body: raw_feed) }

      it { is_expected.to run_successfully }

      it "builds a preview for each item" do
        expect(result[:preview].first).to include(
          "title" => "Poll Feed Spec Fixture",
          "status" => "would_import",
        )
        expect(result[:fetched].items.size).to eq(1)
      end
    end

    context "when an item has already been imported" do
      before do
        stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
        TopicEmbed.import(
          Discourse.system_user,
          "https://blog.discourse.org/2017/09/poll-feed-spec-fixture/",
          "Poll Feed Spec Fixture",
          "content",
        )
      end

      it { is_expected.to run_successfully }

      it "flags the item as already imported with a topic_url" do
        item = result[:preview].first
        expect(item["status"]).to eq("already_imported")
        expect(item["topic_url"]).to be_present
      end
    end
  end
end
