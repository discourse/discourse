# frozen_string_literal: true

require 'rails_helper'

describe IntegerSettingValidator do
  describe '#valid_value?' do

    shared_examples "for all IntegerSettingValidator opts" do
      it "returns false for blank values" do
        expect(validator.valid_value?('')).to eq(false)
        expect(validator.valid_value?(nil)).to eq(false)
      end

      it "returns false if value is not a valid integer" do
        expect(validator.valid_value?('two')).to eq(false)
      end
    end

    context "without min and max" do
      subject(:validator) { described_class.new }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is a valid integer" do
        expect(validator.valid_value?(1)).to eq(true)
        expect(validator.valid_value?('1')).to eq(true)
      end

      it "defaults min to 0" do
        expect(validator.valid_value?(-1)).to eq(false)
        expect(validator.valid_value?('-1')).to eq(false)
        expect(validator.valid_value?(0)).to eq(true)
        expect(validator.valid_value?('0')).to eq(true)
      end

      it "defaults max to 2_000_000_000" do
        expect(validator.valid_value?(2_000_000_001)).to eq(false)
        expect(validator.valid_value?('2000000001')).to eq(false)
        expect(validator.valid_value?(2_000_000_000)).to eq(true)
        expect(validator.valid_value?('2000000000')).to eq(true)
      end
    end

    context "with min" do
      subject(:validator) { described_class.new(min: 2) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is equal to min" do
        expect(validator.valid_value?(2)).to eq(true)
        expect(validator.valid_value?('2')).to eq(true)
      end

      it "returns true if value is greater than min" do
        expect(validator.valid_value?(3)).to eq(true)
        expect(validator.valid_value?('3')).to eq(true)
      end

      it "returns false if value is less than min" do
        expect(validator.valid_value?(1)).to eq(false)
        expect(validator.valid_value?('1')).to eq(false)
      end
    end

    context "with max" do
      subject(:validator) { described_class.new(max: 3) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is equal to max" do
        expect(validator.valid_value?(3)).to eq(true)
        expect(validator.valid_value?('3')).to eq(true)
      end

      it "returns true if value is less than max" do
        expect(validator.valid_value?(2)).to eq(true)
        expect(validator.valid_value?('2')).to eq(true)
      end

      it "returns false if value is greater than min" do
        expect(validator.valid_value?(4)).to eq(false)
        expect(validator.valid_value?('4')).to eq(false)
      end
    end

    context "with min and max" do
      subject(:validator) { described_class.new(min: -1, max: 3) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is in range" do
        expect(validator.valid_value?(-1)).to eq(true)
        expect(validator.valid_value?(0)).to eq(true)
        expect(validator.valid_value?(3)).to eq(true)
      end

      it "returns false if value is out of range" do
        expect(validator.valid_value?(4)).to eq(false)
        expect(validator.valid_value?(-2)).to eq(false)
      end
    end

    context "when setting is hidden" do
      subject(:validator) { described_class.new(hidden: true) }

      it "does not impose default validations" do
        expect(validator.valid_value?(-1)).to eq(true)
        expect(validator.valid_value?(20001)).to eq(true)
      end
    end
  end
end
