# frozen_string_literal: true

RSpec.describe UserFullNameValidator do
  subject(:validate) { validator.validate_each(record, :name, name_state[:value]) }

  let(:validator) { described_class.new(attributes: :name) }
  let(:name_state) { {} }
  let(:record) { Fabricate.build(:user, name: name_state[:value]) }

  context "when name is not required" do
    before { SiteSetting.full_name_requirement = "optional_at_signup" }

    it "allows no name" do
      name_state[:value] = nil
      validate
      expect(record.errors[:name]).not_to be_present
    end

    it "allows name being set" do
      name_state[:value] = "Bigfoot"
      validate
      expect(record.errors[:name]).not_to be_present
    end
  end

  context "when name is required" do
    before { SiteSetting.full_name_requirement = "required_at_signup" }

    it "adds error for nil name" do
      name_state[:value] = nil
      validate
      expect(record.errors[:name]).to be_present
    end

    it "adds error for empty string name" do
      name_state[:value] = ""
      validate
      expect(record.errors[:name]).to be_present
    end

    it "allows name being set" do
      name_state[:value] = "Bigfoot"
      validate
      expect(record.errors[:name]).not_to be_present
    end
  end
end
