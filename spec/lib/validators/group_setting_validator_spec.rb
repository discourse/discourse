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

    it "returns true if value matches an existing group name" do
      expect(validator.valid_value?(group.name)).to eq(true)
    end

    it "returns false if value does not match a group id" do
      expect(validator.valid_value?("-9999")).to eq(false)
    end

    it "returns false for a non-numeric value that does not match a group name" do
      expect(validator.valid_value?("notagroup")).to eq(false)
    end
  end
end
