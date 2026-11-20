# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryTag do
  fab!(:query)

  describe ".normalize_all" do
    it "normalizes all tag names consistently" do
      expect(described_class.normalize_all([" Ops ", "OPS", "a  \t b", "Default", "", nil])).to eq(
        ["ops", "a b", "default"],
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

    it "rejects more than the allowed number of tags" do
      expect {
        described_class.sync!(query:, names: 11.times.map { |index| "tag-#{index}" })
      }.to raise_error(
        ActiveRecord::RecordInvalid,
        "Validation failed: A query can have at most 10 tags, not counting automatic tags.",
      )

      expect(query.tags).to be_empty
    end

    it "doesn't count automatic tags toward the limit" do
      names = 10.times.map { |index| "tag-#{index}" }
      bundled_query = DiscourseDataExplorer::Query.find(-1)
      bundled_query.save!

      described_class.sync!(query:, names: ["custom", *names])
      described_class.sync!(query: bundled_query, names: ["default", "users", *names])

      expect(query.tags.size).to eq(10)
      expect(bundled_query.tags.size).to eq(10)
    end

    it "reserves the default tag for system queries" do
      expect { described_class.sync!(query:, names: ["Default"]) }.to raise_error(
        ActiveRecord::RecordInvalid,
        "Validation failed: The default tag is reserved for system queries.",
      )

      expect(query.tags).to be_empty
    end

    it "stores only additional tags for bundled queries" do
      bundled_query = DiscourseDataExplorer::Query.find(-1)
      bundled_query.save!

      described_class.sync!(query: bundled_query, names: %w[Default Staff])

      expect(bundled_query.tag_names).to eq(%w[default users staff])
      expect(bundled_query.tags.map(&:name)).to eq(["staff"])
    end

    it "reserves the custom tag for user-created queries" do
      bundled_query = DiscourseDataExplorer::Query.find(-1)
      bundled_query.save!

      expect { described_class.sync!(query: bundled_query, names: ["Custom"]) }.to raise_error(
        ActiveRecord::RecordInvalid,
        "Validation failed: The custom tag is reserved for user-created queries.",
      )
    end

    it "keeps the custom tag virtual for user-created queries" do
      described_class.sync!(query:, names: %w[Custom Ops])

      expect(query.tag_names).to eq(%w[custom ops])
      expect(query.tags.map(&:name)).to eq(["ops"])
      expect(described_class.exists?(name: "custom")).to eq(false)
    end

    it "keeps automatic tags virtual for bundled queries" do
      bundled_query = DiscourseDataExplorer::Query.find(-42)
      bundled_query.save!

      described_class.sync!(query: bundled_query, names: %w[Traffic Staff])

      expect(bundled_query.tag_names).to eq(%w[default traffic staff])
      expect(bundled_query.tags.map(&:name)).to eq(["staff"])
      expect(described_class.exists?(name: "traffic")).to eq(false)
    end
  end
end
