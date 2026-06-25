# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Action::FetchFeed do
  subject(:result) { described_class.call(feed_url:) }

  let(:feed_url) { "https://blog.discourse.org/feed/" }
  let(:raw_feed) { file_from_fixtures("feed.rss", "feed") }

  context "when the feed is fetched and parsed successfully" do
    before { stub_request(:get, feed_url).to_return(status: 200, body: raw_feed) }

    it "returns the parsed feed items with no error" do
      expect(result.error).to be_nil
      expect(result.items.size).to eq(1)
      expect(result.items.first).to be_a(DiscourseRssPolling::FeedItem)
      expect(result.items.first.title).to eq("Poll Feed Spec Fixture")
    end
  end

  context "when the HTTP request fails" do
    before { stub_request(:get, feed_url).to_return(status: 500) }

    it "returns a fetch_failed error and no items" do
      expect(result.error).to eq(:fetch_failed)
      expect(result.items).to be_empty
    end
  end

  context "when the body is valid XML but not a feed" do
    before do
      stub_request(:get, feed_url).to_return(
        status: 200,
        body: "<html><body>not a feed</body></html>",
      )
    end

    it "returns a parse_failed error and no items" do
      expect(result.error).to eq(:parse_failed)
      expect(result.items).to be_empty
    end
  end

  context "when fetching raises an unexpected error" do
    before { FinalDestination.any_instance.stubs(:get).raises(StandardError.new("boom")) }

    it "returns a fetch_failed error instead of raising" do
      expect(result.error).to eq(:fetch_failed)
      expect(result.items).to be_empty
    end
  end
end
