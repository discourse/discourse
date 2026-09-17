# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryTag do
  fab!(:query)

  describe ".normalize_all" do
    it "normalizes names while preserving the system tag's display value" do
      expect(described_class.normalize_all([" Ops ", "OPS", "a  \t b", "default", "", nil])).to eq(
        ["ops", "a b", "Default"],
      )
    end
  end

  describe ".sync!" do
    fab!(:other_query, :query)

    it "assigns normalized tags to the query" do
      described_class.sync!(query:, names: ["Ops", " billing "])

      expect(query.tags.map(&:name)).to eq(%w[billing ops])
    end

    it "removes orphaned tags while retaining tags used by another query" do
      described_class.sync!(query:, names: %w[ops billing])
      described_class.sync!(query: other_query, names: %w[ops])
      described_class.sync!(query:, names: [])

      expect(query.tags).to be_empty
      expect(other_query.tags.map(&:name)).to eq(%w[ops])
      expect(described_class.pluck(:name)).to contain_exactly("ops")
    end

    it "always assigns the Default tag to bundled queries" do
      default_query = DiscourseDataExplorer::Query.find(-1)
      default_query.save!

      described_class.sync!(query: default_query, names: ["ops"])
      described_class.sync!(query: default_query, names: [])

      expect(default_query.tag_names).to eq(["Default"])
    end

    it "rejects more than the allowed number of tags" do
      expect {
        described_class.sync!(query:, names: 11.times.map { |index| "tag-#{index}" })
      }.to raise_error(
        ActiveRecord::RecordInvalid,
        "Validation failed: A query can have at most 10 tags.",
      )

      expect(query.tags).to be_empty
    end
  end
end
