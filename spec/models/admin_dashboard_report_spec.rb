# frozen_string_literal: true

RSpec.describe AdminDashboardReport do
  describe "validations" do
    it "requires source, identifier, and position" do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors.attribute_names).to include(:source, :identifier, :position)
    end

    it "enforces uniqueness on (source, identifier)" do
      described_class.create!(source: "core_report", identifier: "signups", position: 0)

      duplicate = described_class.new(source: "core_report", identifier: "signups", position: 1)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.attribute_names).to include(:identifier)
    end

    it "allows the same identifier under a different source" do
      described_class.create!(source: "core_report", identifier: "signups", position: 0)

      other_source =
        described_class.new(source: "data_explorer_query", identifier: "signups", position: 1)
      expect(other_source).to be_valid
    end
  end
end
