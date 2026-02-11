# frozen_string_literal: true

RSpec.describe TagSerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:tag)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:topic_in_public_category) { Fabricate(:topic, tags: [tag]) }
  fab!(:topic_in_private_category) { Fabricate(:topic, category: private_category, tags: [tag]) }

  describe "#slug" do
    it "includes the slug attribute" do
      serialized = described_class.new(tag, scope: Guardian.new(user), root: false).as_json
      expect(serialized[:slug]).to eq(tag.slug)
    end

    it "uses slug_for_url when slug is empty" do
      numeric_tag = Fabricate(:tag, name: "123")
      expect(numeric_tag.slug).to eq("")

      serialized = described_class.new(numeric_tag, scope: Guardian.new(user), root: false).as_json
      expect(serialized[:slug]).to eq("#{numeric_tag.id}-tag")
    end
  end

  describe "#topic_count" do
    it "should return the value of `Tag#public_topic_count` for a non-staff user" do
      serialized = described_class.new(tag, scope: Guardian.new(user), root: false).as_json

      expect(serialized[:topic_count]).to eq(1)
    end

    it "should return the value of `Tag#topic_count` for a staff user" do
      serialized = described_class.new(tag, scope: Guardian.new(admin), root: false).as_json

      expect(serialized[:topic_count]).to eq(2)
    end
  end
end
