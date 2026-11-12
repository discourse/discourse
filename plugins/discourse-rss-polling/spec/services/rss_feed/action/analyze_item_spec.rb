# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Action::AnalyzeItem do
  subject(:analysis) { described_class.call(feed_item:, feed_category_filter:) }

  let(:feed_category_filter) { nil }

  let(:feed_item) do
    instance_double(
      DiscourseRssPolling::FeedItem,
      title: "A title",
      content: "Some content",
      categories: ["Announcements"],
      url: "https://example.com/post",
    )
  end

  it "would import an item with a title and content" do
    expect(analysis).to eq([described_class::WOULD_IMPORT, nil])
  end

  it "skips an item without content" do
    allow(feed_item).to receive(:content).and_return("")

    expect(analysis).to eq([described_class::SKIPPED, :missing_content])
  end

  it "skips an item without a title" do
    allow(feed_item).to receive(:title).and_return(nil)

    expect(analysis).to eq([described_class::SKIPPED, :missing_title])
  end

  it "skips an item without a valid http(s) link" do
    allow(feed_item).to receive(:url).and_return("urn:uuid:1234")

    expect(analysis).to eq([described_class::SKIPPED, :invalid_url])
  end

  context "with a category filter" do
    let(:feed_category_filter) { "announce" }

    it "would import an item whose category matches the filter" do
      expect(analysis).to eq([described_class::WOULD_IMPORT, nil])
    end

    it "matches the filter case-insensitively" do
      allow(feed_item).to receive(:categories).and_return(["ANNOUNCEMENTS"])

      expect(analysis).to eq([described_class::WOULD_IMPORT, nil])
    end

    it "skips an item whose categories do not match the filter" do
      allow(feed_item).to receive(:categories).and_return(["Random"])

      expect(analysis).to eq([described_class::SKIPPED, :category_filter_mismatch])
    end
  end
end
