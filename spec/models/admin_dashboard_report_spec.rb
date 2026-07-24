# frozen_string_literal: true

RSpec.describe AdminDashboardReport do
  let(:another_provider) do
    Class.new(AdminDashboard::Reports::SourceProvider) { def self.source_name = "another_source" }
  end

  before do
    DiscoursePluginRegistry.register_admin_dashboard_report_source(
      another_provider,
      Plugin::Instance.new,
    )
  end

  after do
    DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
      entry[:value] == another_provider
    end
  end

  describe "validations" do
    it "requires source and identifier" do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors.attribute_names).to include(:source, :identifier)
    end

    it "enforces uniqueness on (source, identifier)" do
      described_class.create!(source: "core_report", identifier: "signups")

      duplicate = described_class.new(source: "core_report", identifier: "signups")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.attribute_names).to include(:identifier)
    end

    it "allows the same identifier under a different source" do
      described_class.create!(source: "core_report", identifier: "signups")

      other_source = described_class.new(source: "another_source", identifier: "signups")
      expect(other_source).to be_valid
    end

    it "rejects sources without a registered provider" do
      record = described_class.new(source: "totally_unregistered", identifier: "x")
      expect(record).not_to be_valid
      expect(record.errors.attribute_names).to include(:source)
    end
  end

  describe "default position" do
    before { described_class.delete_all }

    it "assigns position 1 when there are no existing rows" do
      record = described_class.create!(source: "core_report", identifier: "signups")
      expect(record.position).to eq(1)
    end

    it "assigns the next position when rows already exist" do
      described_class.create!(source: "core_report", identifier: "signups", position: 4)
      described_class.create!(source: "core_report", identifier: "topics", position: 9)

      latest = described_class.create!(source: "core_report", identifier: "page_view_total_reqs")
      expect(latest.position).to eq(10)
    end

    it "honours an explicitly-provided position" do
      record = described_class.create!(source: "core_report", identifier: "signups", position: 42)
      expect(record.position).to eq(42)
    end
  end
end
