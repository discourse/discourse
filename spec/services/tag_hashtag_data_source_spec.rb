# frozen_string_literal: true

RSpec.describe TagHashtagDataSource do
  fab!(:tag1) { Fabricate(:tag, name: "fact") }
  fab!(:tag2) { Fabricate(:tag, name: "factor", topic_count: 5) }
  fab!(:tag3) { Fabricate(:tag, name: "factory", topic_count: 1) }
  fab!(:tag4) { Fabricate(:tag, name: "factorio") }
  fab!(:tag5) { Fabricate(:tag, name: "factz") }
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }

  describe "#search" do
    it "orders tag results by exact search match, then topic count, then name" do
      expect(described_class.search(guardian, "fact", 5).map(&:slug)).to eq(
        %w[fact factor factory factorio factz],
      )
    end

    it "does not get more than the limit" do
      expect(described_class.search(guardian, "fact", 1).map(&:slug)).to eq(%w[fact])
    end

    it "does not get tags that the user does not have permission to see" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["fact"])
      expect(described_class.search(guardian, "fact", 5).map(&:slug)).not_to include("fact")
    end

    it "returns an array of HashtagAutocompleteService::HashtagItem" do
      expect(described_class.search(guardian, "fact", 1).first).to be_a(
        HashtagAutocompleteService::HashtagItem,
      )
    end

    it "includes the topic count for the text of the tag" do
      expect(described_class.search(guardian, "fact", 5).map(&:text)).to eq(
        ["fact x 0", "factor x 5", "factory x 1", "factorio x 0", "factz x 0"],
      )
    end

    it "returns nothing if tagging is not enabled" do
      SiteSetting.tagging_enabled = false
      expect(described_class.search(guardian, "fact", 5)).to be_empty
    end
  end

  describe "#search_without_term" do
    fab!(:topic1) { Fabricate(:topic, tags: [tag4]) }
    fab!(:topic2) { Fabricate(:topic, tags: [tag5]) }
    fab!(:topic3) { Fabricate(:topic, tags: [tag2]) }
    fab!(:topic4) { Fabricate(:topic, tags: [tag3]) }
    fab!(:topic5) { Fabricate(:topic, tags: [tag1]) }
    fab!(:post1) { Fabricate(:post, topic: topic1, created_at: 1.day.ago) }
    fab!(:post2) { Fabricate(:post, topic: topic1, created_at: 6.hours.ago) }
    fab!(:post3) { Fabricate(:post, topic: topic2, created_at: 1.hour.ago) }
    fab!(:post4) { Fabricate(:post, topic: topic3, created_at: 3.days.ago) }
    fab!(:post5) { Fabricate(:post, topic: topic4, created_at: 1.week.ago) }
    fab!(:post6) { Fabricate(:post, topic: topic4, created_at: 2.minutes.ago) }
    fab!(:post7) { Fabricate(:post, topic: topic5, created_at: 3.weeks.ago) }

    it "returns distinct tags attached to topics with posts that have been recently created in the past 2 weeks" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to match_array(
        %w[factor factory factorio factz],
      )
    end

    it "does not return recent tags for posts created > 2 weeks ago" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include(
        "fact",
      )
    end

    it "does not return tags the user does not have permission to view" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["factor"])
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end

    it "does not return tags where the post that would match is deleted" do
      post4.trash!
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end

    it "does not return tags for deleted topics" do
      topic1.trash!
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factorio")
    end
  end
end
