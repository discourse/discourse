# frozen_string_literal: true

RSpec.describe AdminDashboard::Reports::Section do
  fab!(:admin)
  let(:guardian) { admin.guardian }

  let(:fake_provider) do
    Class.new(AdminDashboard::Reports::SourceProvider) do
      def self.source_name = "fake"

      def self.label = "Fake"

      def self.resolve_many(identifiers, guardian:)
        identifiers
          .reject { |id| id.to_s.start_with?("missing_") }
          .each_with_object({}) do |id, hash|
            hash[id.to_s] = AdminDashboard::Reports::ResolvedReport.new(
              source: "fake",
              identifier: id.to_s,
              title: "Title for #{id}",
              description: "Desc for #{id}",
              label: label,
              url: "/fake/#{id}",
            )
          end
      end
    end
  end

  let(:plugin) { Plugin::Instance.new }

  before do
    AdminDashboardReport.delete_all
    DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
  end

  after do
    DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
      entry[:value] == fake_provider
    end
  end

  it "returns an empty items list when there are no rows" do
    result = described_class.build(guardian: guardian)
    expect(result[:items]).to eq([])
  end

  it "returns items in position order, ignoring insertion order" do
    AdminDashboardReport.create!(source: "fake", identifier: "a", position: 1)
    AdminDashboardReport.create!(source: "fake", identifier: "b", position: 0)
    AdminDashboardReport.create!(source: "fake", identifier: "c", position: 2)

    result = described_class.build(guardian: guardian)
    expect(result[:items].map { |item| item[:identifier] }).to eq(%w[b a c])
  end

  it "serializes the resolved metadata along with a composite key" do
    AdminDashboardReport.create!(source: "fake", identifier: "x", position: 0)

    item = described_class.build(guardian: guardian)[:items].first
    expect(item).to eq(
      source: "fake",
      identifier: "x",
      title: "Title for x",
      description: "Desc for x",
      label: "Fake",
      url: "/fake/x",
      key: "fake:x",
    )
  end

  it "drops rows whose source has no registered provider" do
    AdminDashboardReport.create!(source: "fake", identifier: "good", position: 0)
    orphan = AdminDashboardReport.create!(source: "fake", identifier: "becomes_orphan", position: 1)
    orphan.update_column(:source, "unregistered_source")

    result = described_class.build(guardian: guardian)
    expect(result[:items].map { |item| item[:identifier] }).to eq(%w[good])
  end

  it "drops rows the provider declines to resolve" do
    AdminDashboardReport.create!(source: "fake", identifier: "good", position: 0)
    AdminDashboardReport.create!(source: "fake", identifier: "missing_one", position: 1)

    result = described_class.build(guardian: guardian)
    expect(result[:items].map { |item| item[:identifier] }).to eq(%w[good])
  end

  it "caps at VISIBLE_CAP, dropping the oldest rows by created_at" do
    stub_const(AdminDashboardReport, :VISIBLE_CAP, 3) do
      5.times do |index|
        AdminDashboardReport.create!(
          source: "fake",
          identifier: "r_#{index}",
          position: index,
          created_at: index.minutes.ago,
        )
      end

      result = described_class.build(guardian: guardian)
      identifiers = result[:items].map { |item| item[:identifier] }

      expect(identifiers).to eq(%w[r_0 r_1 r_2])
    end
  end
end
