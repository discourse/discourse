# frozen_string_literal: true

RSpec.describe DatetimeSettingValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?("")).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true for valid ISO 8601 datetime with Z suffix" do
      expect(validator.valid_value?("2024-12-29T15:30:00Z")).to eq(true)
    end

    it "returns true for valid ISO 8601 datetime with timezone offset" do
      expect(validator.valid_value?("2024-12-29T15:30:00+05:30")).to eq(true)
    end

    it "returns false for invalid datetime strings" do
      expect(validator.valid_value?("not a datetime")).to eq(false)
    end
  end
end
