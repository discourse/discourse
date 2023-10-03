# frozen_string_literal: true

RSpec.describe TagHashtagDataSource do
  fab!(:tag1) { Fabricate(:tag, name: "fact", public_topic_count: 0) }
  fab!(:tag2) { Fabricate(:tag, name: "factor", public_topic_count: 5) }
  fab!(:tag3) { Fabricate(:tag, name: "factory", public_topic_count: 4) }
  fab!(:tag4) { Fabricate(:tag, name: "factorio", public_topic_count: 3) }
  fab!(:tag5) { Fabricate(:tag, name: "factz", public_topic_count: 1) }
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }

  describe "#enabled?" do
    it "returns false if tagging is disabled" do
      SiteSetting.tagging_enabled = false
      expect(described_class.enabled?).to eq(false)
    end

    it "returns true if tagging is enabled" do
      SiteSetting.tagging_enabled = true
      expect(described_class.enabled?).to eq(true)
    end
  end

  describe "#search" do
    it "orders tag results by exact search match, then public topic count, then name" do
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

    it "includes the public topic count for the text of the tag in secondary text" do
      expect(described_class.search(guardian, "fact", 5).map(&:secondary_text)).to eq(
        %w[x0 x5 x4 x3 x1],
      )
    end

    it "returns tags that are children of a TagGroup" do
      parent_tag = Fabricate(:tag, name: "sidebar")
      child_tag = Fabricate(:tag, name: "sidebar-v1")
      tag_group = Fabricate(:tag_group, parent_tag: parent_tag, name: "Sidebar TG")
      TagGroupMembership.create!(tag: child_tag, tag_group: tag_group)
      expect(described_class.search(guardian, "sidebar-v", 5).map(&:slug)).to eq(%w[sidebar-v1])
    end
  end

  describe "#search_without_term" do
    it "returns distinct tags sorted by public topic count" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(
        %w[factor factory factorio factz fact],
      )
    end

    it "does not return tags the user does not have permission to view" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["factor"])
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end

    it "does not return tags the user has muted" do
      TagUser.create(user: user, tag: tag2, notification_level: TagUser.notification_levels[:muted])
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end
  end
end
