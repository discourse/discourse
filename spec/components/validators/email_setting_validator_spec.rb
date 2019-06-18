# frozen_string_literal: true

require 'rails_helper'

describe EmailSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?('')).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value is a valid email address" do
      expect(validator.valid_value?('vader@example.com')).to eq(true)
    end

    it "returns false if value is not a valid email address" do
      expect(validator.valid_value?('my house')).to eq(false)
    end
  end
end
