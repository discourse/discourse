# frozen_string_literal: true

require 'rails_helper'

describe SelectableAvatarsEnabledValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true when disabling" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("f")).to eq(true)

      SiteSetting.selectable_avatars = [Fabricate(:image_upload).url, Fabricate(:image_upload).url].join("\n")
      expect(validator.valid_value?("f")).to eq(true)
    end

    it "returns true when there are at least two selectable avatars" do
      SiteSetting.selectable_avatars = [Fabricate(:image_upload).url, Fabricate(:image_upload).url].join("\n")
      expect(validator.valid_value?("t")).to eq(true)
    end

    it "returns false when selectable avatars is blank or has one avatar" do
      SiteSetting.selectable_avatars = ""
      expect(validator.valid_value?("t")).to eq(false)

      SiteSetting.selectable_avatars = Fabricate(:image_upload).url
      expect(validator.valid_value?("t")).to eq(false)
    end
  end
end
