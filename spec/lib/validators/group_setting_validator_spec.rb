# frozen_string_literal: true

RSpec.describe GroupSettingValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    fab!(:group) { Fabricate(:group, name: "hello") }

    it "returns true for blank values" do
      expect(validator.valid_value?("")).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value matches an existing group id" do
      expect(validator.valid_value?(group.id.to_s)).to eq(true)
    end

    it "returns false if value matches a group name rather than an id" do
      expect(validator.valid_value?(group.name)).to eq(false)
    end

    it "returns false if value does not match a group id" do
      expect(validator.valid_value?("999999999")).to eq(false)
    end

    it "does not read a group id out of a value that merely starts with a digit" do
      expect(validator.valid_value?("0#{group.name}")).to eq(false)
    end
  end
end
