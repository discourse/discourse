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
end
