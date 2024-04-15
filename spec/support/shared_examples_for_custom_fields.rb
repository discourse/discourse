# frozen_string_literal: true

RSpec.shared_examples_for "it has custom fields" do
  let(:record) { described_class.new }

  describe "Max number of custom fields" do
    let(:custom_fields) { (1..101).to_a.product(["value"]).to_h }

    before { record.custom_fields = custom_fields }

    it "can't have more than 100 custom fields" do
      expect(record).to be_invalid
      expect(record.errors[:base]).to include(/Maximum number.*\(100\)/)
    end
  end

  describe "Max length of a custom field" do
    let(:bad_value) { "a" * 10_000_001 }

    before { record.custom_fields[:my_custom_field] = bad_value }

    it "can't have more than 10,000,000 characters" do
      expect(record).to be_invalid
      expect(record.errors[:base]).to include(/Maximum length.*\(10000000\)/)
    end
  end
end
