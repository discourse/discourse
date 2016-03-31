require 'rails_helper'

describe UsernameSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?('')).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value matches an existing user's username" do
      Fabricate(:user, username: 'vader')
      expect(validator.valid_value?('vader')).to eq(true)
    end

    it "returns false if value does not match a user's username" do
      expect(validator.valid_value?('no way')).to eq(false)
    end
  end
end
