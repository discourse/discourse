# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Action::BuildPreview do
  subject(:preview) { described_class.call(feed_items:, feed_category_filter:) }

  let(:feed_category_filter) { nil }
  let(:title) { "Hello" }
  let(:content) { "Body" }
  let(:categories) { [] }
  let(:url) { "https://example.com/post" }
  let(:feed_item) do
    instance_double(DiscourseRssPolling::FeedItem, title:, content:, categories:, url:)
  end
  let(:feed_items) { [feed_item] }

  before do
    allow(feed_item).to receive(:outcome) do |status:, reason: nil, topic_url: nil|
      {
        "title" => title,
        "status" => status.to_s,
        "reason" => reason&.to_s,
        "topic_url" => topic_url,
      }
    end
  end

  context "when an item would be imported" do
    it "marks the item as would_import" do
      expect(preview.first).to include("status" => "would_import", "topic_url" => nil)
    end
  end

  context "when an item is skipped" do
    let(:title) { nil }

    it "marks the item as skipped with a reason" do
      expect(preview.first).to include("status" => "skipped", "reason" => "missing_title")
    end
  end

  context "when an item has already been imported" do
    let(:imported_url) { "https://blog.discourse.org/2017/09/poll-feed-spec-fixture/" }
    let(:url) { imported_url }

    before do
      TopicEmbed.import(Discourse.system_user, imported_url, "Poll Feed Spec Fixture", "content")
    end

    it "marks the item as already_imported with the existing topic url" do
      item = preview.first
      expect(item["status"]).to eq("already_imported")
      expect(item["topic_url"]).to be_present
    end
  end
end
