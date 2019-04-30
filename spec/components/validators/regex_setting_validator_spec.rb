# frozen_string_literal: true

require 'rails_helper'

describe RegexSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?('')).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "return false for invalid regex" do
      expect(validator.valid_value?('(()')).to eq(false)
    end

    it "returns false for regex with dangerous matches" do
      expect(validator.valid_value?('(.)*')).to eq(false)
    end

    it "returns true for safe regex" do
      expect(validator.valid_value?('\d{3}-\d{4}')).to eq(true)
    end
  end
end
