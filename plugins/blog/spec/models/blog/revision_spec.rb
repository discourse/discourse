# frozen_string_literal: true

RSpec.describe Blog::Revision do
  describe "#public_tags" do
    fab!(:tag) { Fabricate(:tag, name: "field-notes") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "staff-notes") }
    fab!(:tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    it "returns only tags everyone can see" do
      revision = described_class.new(data: { "tags" => [tag.name, hidden_tag.name, "missing-tag"] })

      expect(revision.public_tags).to contain_exactly(tag)
    end
  end

  describe "#absolute_image_url" do
    it "returns the absolute image URL when the revision has one" do
      expect(described_class.new(data: { "image_url" => "" }).absolute_image_url).to be_nil
      expect(
        described_class.new(data: { "image_url" => "/uploads/cover.png" }).absolute_image_url,
      ).to eq("http://test.localhost/uploads/cover.png")
    end
  end
end
