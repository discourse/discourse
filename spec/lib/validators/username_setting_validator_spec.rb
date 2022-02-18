# frozen_string_literal: true

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

    context "regex support" do
      fab!(:darthvader) { Fabricate(:user, username: 'darthvader') }
      fab!(:luke) { Fabricate(:user, username: 'luke') }

      it "returns false if regex doesn't match" do
        v = described_class.new(regex: 'darth')
        expect(v.valid_value?('luke')).to eq(false)
        expect(v.valid_value?('vader')).to eq(false)
      end

      it "returns true if regex matches" do
        v = described_class.new(regex: 'darth')
        expect(v.valid_value?('darthvader')).to eq(true)
      end

      it "returns false if regex matches but username doesn't match a user" do
        v = described_class.new(regex: 'darth')
        expect(v.valid_value?('darthmaul')).to eq(false)
      end
    end
  end
end
