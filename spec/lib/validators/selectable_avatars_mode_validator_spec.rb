# frozen_string_literal: true

RSpec.describe SelectableAvatarsModeValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    it "returns true when disabling" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("disabled")).to eq(true)

      SiteSetting.selectable_avatars = [Fabricate(:image_upload), Fabricate(:image_upload)]
      expect(validator.valid_value?("disabled")).to eq(true)
    end

    it "returns true when there are at least two selectable avatars" do
      SiteSetting.selectable_avatars = [Fabricate(:image_upload), Fabricate(:image_upload)]
      expect(validator.valid_value?("no_one")).to eq(true)
    end

    it "returns false when selectable avatars is blank or has one avatar" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("no_one")).to eq(false)

      SiteSetting.selectable_avatars = [Fabricate(:image_upload)]
      expect(validator.valid_value?("no_one")).to eq(false)
    end
  end
end
