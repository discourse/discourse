# frozen_string_literal: true

require 'rails_helper'

describe SelectableAvatarsEnabledValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true when disabling" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("none")).to eq(true)

      SiteSetting.selectable_avatars = [Fabricate(:image_upload), Fabricate(:image_upload)]
      expect(validator.valid_value?("none")).to eq(true)
    end

    it "returns true when there are at least two selectable avatars" do
      SiteSetting.selectable_avatars = [Fabricate(:image_upload), Fabricate(:image_upload)]
      expect(validator.valid_value?("restrict_all")).to eq(true)
    end

    it "returns false when selectable avatars is blank or has one avatar" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("restrict_all")).to eq(false)

      SiteSetting.selectable_avatars = [Fabricate(:image_upload)]
      expect(validator.valid_value?("restrict_all")).to eq(false)
    end
  end
end
