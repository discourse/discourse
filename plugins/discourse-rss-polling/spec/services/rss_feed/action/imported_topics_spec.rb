# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Action::ImportedTopics do
  subject(:imported) { described_class.call(feed_items:) }

  let(:imported_url) { "https://blog.discourse.org/2017/09/poll-feed-spec-fixture/" }
  let(:other_url) { "https://blog.discourse.org/2018/01/not-imported/" }

  let(:imported_item) { instance_double(DiscourseRssPolling::FeedItem, url: imported_url) }
  let(:other_item) { instance_double(DiscourseRssPolling::FeedItem, url: other_url) }

  let(:feed_items) { [imported_item, other_item] }

  context "when an item has a matching imported topic" do
    before do
      TopicEmbed.import(Discourse.system_user, imported_url, "Poll Feed Spec Fixture", "content")
    end

    it "returns the topic url only for the imported item" do
      expect(imported.keys).to contain_exactly(imported_item)
      expect(imported[imported_item]).to be_present
    end
  end

  context "when no item has been imported" do
    it "returns an empty map" do
      expect(imported).to be_empty
    end
  end
end
