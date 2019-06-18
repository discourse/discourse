# frozen_string_literal: true

require "rails_helper"

describe UserFullNameValidator do
  let(:validator) { described_class.new(attributes: :name) }
  subject(:validate) { validator.validate_each(record, :name, @name) }
  let(:record) { Fabricate.build(:user, name: @name) }

  context "name not required" do
    before { SiteSetting.full_name_required = false }

    it "allows no name" do
      @name = nil
      validate
      expect(record.errors[:name]).not_to be_present
    end

    it "allows name being set" do
      @name = "Bigfoot"
      validate
      expect(record.errors[:name]).not_to be_present
    end
  end

  context "name required" do
    before { SiteSetting.full_name_required = true }

    it "adds error for nil name" do
      @name = nil
      validate
      expect(record.errors[:name]).to be_present
    end

    it "adds error for empty string name" do
      @name = ""
      validate
      expect(record.errors[:name]).to be_present
    end

    it "allows name being set" do
      @name = "Bigfoot"
      validate
      expect(record.errors[:name]).not_to be_present
    end
  end
end
