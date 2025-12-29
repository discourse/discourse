# frozen_string_literal: true

RSpec.describe DatetimeSettingValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?("")).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    context "with valid datetime values" do
      it "returns true for UTC datetime with Z suffix" do
        expect(validator.valid_value?("2024-12-29T15:30:00Z")).to eq(true)
        expect(validator.valid_value?("2024-12-29T15:30:00.000Z")).to eq(true)
      end

      it "returns true for ISO 8601 datetime with timezone offset" do
        expect(validator.valid_value?("2024-12-29T15:30:00+00:00")).to eq(true)
        expect(validator.valid_value?("2024-12-29T15:30:00+05:30")).to eq(true)
        expect(validator.valid_value?("2024-12-29T15:30:00-08:00")).to eq(true)
      end

      it "returns true for datetime with milliseconds" do
        expect(validator.valid_value?("2024-12-29T15:30:00.123Z")).to eq(true)
        expect(validator.valid_value?("2024-12-29T15:30:00.123456Z")).to eq(true)
      end
    end

    context "with invalid datetime values" do
      it "returns false for date-only strings" do
        expect(validator.valid_value?("2024-12-29")).to eq(false)
      end

      it "returns false for datetime without timezone" do
        expect(validator.valid_value?("2024-12-29T15:30:00")).to eq(false)
      end

      it "returns false for invalid datetime strings" do
        expect(validator.valid_value?("not a datetime")).to eq(false)
        expect(validator.valid_value?("2024-13-01T15:30:00Z")).to eq(false)
        expect(validator.valid_value?("2024-12-32T15:30:00Z")).to eq(false)
        expect(validator.valid_value?("2024-12-29T25:00:00Z")).to eq(false)
        expect(validator.valid_value?("2024-12-29T15:60:00Z")).to eq(false)
      end

      it "returns false for time-only strings" do
        expect(validator.valid_value?("15:30:00")).to eq(false)
      end
    end
  end
end
