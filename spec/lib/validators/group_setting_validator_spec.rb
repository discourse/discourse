# frozen_string_literal: true

require 'rails_helper'

describe GroupSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?('')).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value matches an existing group" do
      Fabricate(:group, name: "hello")
      expect(validator.valid_value?('hello')).to eq(true)
    end

    it "returns false if value does not match a group" do
      expect(validator.valid_value?('notagroup')).to eq(false)
    end
  end
end
