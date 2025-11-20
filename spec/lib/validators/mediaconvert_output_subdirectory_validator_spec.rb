# frozen_string_literal: true

require "rails_helper"

RSpec.describe MediaconvertOutputSubdirectoryValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    it "returns true when value is present" do
      expect(validator.valid_value?("transcoded")).to be true
      expect(validator.valid_value?("converted-videos")).to be true
    end

    it "returns false when value is blank" do
      expect(validator.valid_value?("")).to be false
      expect(validator.valid_value?(nil)).to be false
    end
  end

  describe "#error_message" do
    it "returns the correct error message" do
      expect(validator.error_message).to eq(
        I18n.t("site_settings.errors.mediaconvert_output_subdirectory_required"),
      )
    end
  end
end
