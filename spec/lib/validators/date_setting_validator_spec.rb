# frozen_string_literal: true

RSpec.describe DateSettingValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?("")).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value is a valid date" do
      expect(validator.valid_value?("2024-01-15")).to eq(true)
      expect(validator.valid_value?("2024-12-31")).to eq(true)
    end

    it "returns false if value is not a valid date" do
      expect(validator.valid_value?("not a date")).to eq(false)
      expect(validator.valid_value?("2024-13-01")).to eq(false)
      expect(validator.valid_value?("2024-01-32")).to eq(false)
    end
  end
end
