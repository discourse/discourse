# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Query do
  before { SiteSetting.data_explorer_enabled = true }

  describe ".find" do
    it "returns default queries with their automatic tags" do
      query = DiscourseDataExplorer::Query.find(-1)

      expect(query).to be_present
      expect(query.tag_names).to eq(%w[default users])
    end

    it "preserves additional tags while keeping the default tag mandatory" do
      query = DiscourseDataExplorer::Query.find(-1)
      query.save!
      DiscourseDataExplorer::QueryTag.sync!(query:, names: ["Staff"])

      expect(DiscourseDataExplorer::Query.find(-1).tag_names).to eq(%w[default users staff])

      DiscourseDataExplorer::QueryTag.sync!(query:, names: [])

      expect(DiscourseDataExplorer::Query.find(-1).tag_names).to eq(%w[default users])
    end
  end

  describe "#tag_names" do
    it "includes automatic tags for bundled queries" do
      expect(DiscourseDataExplorer::Query.find(-42).tag_names).to eq(%w[default traffic])
    end
  end

  describe "unscoped .find" do
    it "returns default queries" do
      expect(DiscourseDataExplorer::Query.unscoped.find(-1)).to be_present
    end
  end

  describe "#record_run!" do
    it "keeps the default tag virtual after running a bundled query" do
      query = DiscourseDataExplorer::Query.find(-1)

      query.record_run!

      expect(query.tag_names).to eq(%w[default users])
      expect(query.tags).to be_empty
      expect(
        DiscourseDataExplorer::QueryTag.exists?(name: DiscourseDataExplorer::Query::DEFAULT_TAG),
      ).to eq(false)
    end
  end

  describe ".unpersisted_defaults" do
    it "assigns and filters by the default tag" do
      defaults = DiscourseDataExplorer::Query.unpersisted_defaults(tag: "default")

      expect(defaults).to be_present
      expect(defaults.map(&:tag_names)).to all(include("default"))
      expect(DiscourseDataExplorer::Query.unpersisted_defaults(tag: "Custom")).to be_empty
    end

    it "filters by automatic tags" do
      defaults = DiscourseDataExplorer::Query.unpersisted_defaults(tags: %w[default traffic])

      expect(defaults.map(&:id)).to contain_exactly(-20, -42, -43, -44)
      expect(defaults.map(&:tag_names)).to all(eq(%w[default traffic]))
    end

    it "tags content queries" do
      defaults = DiscourseDataExplorer::Query.unpersisted_defaults(tag: "content")

      expect(defaults.map(&:id)).to contain_exactly(-4, -5, -17, -18, -21, -22, -23, -28, -30)
    end

    it "tags engagement queries" do
      defaults = DiscourseDataExplorer::Query.unpersisted_defaults(tag: "engagement")

      expect(defaults.map(&:id)).to contain_exactly(-2, -8, -11, -24, -25, -26, -29, -36)
    end
  end
end
