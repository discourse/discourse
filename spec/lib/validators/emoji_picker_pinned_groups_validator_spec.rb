# frozen_string_literal: true

RSpec.describe EmojiPickerPinnedGroupsValidator do
  subject(:validator) { described_class.new }

  before { Emoji.clear_cache }

  describe "#valid_value?" do
    it "accepts a blank value" do
      expect(validator.valid_value?("")).to be(true)
      expect(validator.valid_value?(nil)).to be(true)
    end

    it "accepts a standard emoji group name" do
      expect(validator.valid_value?("flags")).to be(true)
    end

    it "accepts multiple valid group names" do
      expect(validator.valid_value?("flags|activities")).to be(true)
    end

    it "accepts a custom emoji group name" do
      CustomEmoji.create!(name: "partyblob", upload_id: 9999, group: "reactions")
      Emoji.clear_cache
      expect(validator.valid_value?("reactions")).to be(true)
    end

    it "accepts the default custom group name" do
      CustomEmoji.create!(name: "partyblob", upload_id: 9999, group: nil)
      Emoji.clear_cache
      expect(validator.valid_value?(Emoji::DEFAULT_GROUP)).to be(true)
    end

    it "rejects an unknown group name" do
      expect(validator.valid_value?("nonexistent_group")).to be(false)
    end

    it "rejects a mix of valid and invalid group names" do
      expect(validator.valid_value?("flags|nonexistent_group")).to be(false)
    end
  end

  describe "#error_message" do
    it "lists the invalid group names" do
      validator.valid_value?("flags|bad_group|another_bad")
      expect(validator.error_message).to include("bad_group", "another_bad")
    end
  end
end
