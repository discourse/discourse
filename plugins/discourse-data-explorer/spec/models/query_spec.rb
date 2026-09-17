# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Query do
  before { SiteSetting.data_explorer_enabled = true }

  describe ".find" do
    it "returns default queries with the default tag" do
      query = DiscourseDataExplorer::Query.find(-1)

      expect(query).to be_present
      expect(query.tag_names).to eq([DiscourseDataExplorer::Query::DEFAULT_TAG])
    end

    it "preserves additional tags while keeping the default tag mandatory" do
      query = DiscourseDataExplorer::Query.find(-1)
      query.save!
      DiscourseDataExplorer::QueryTag.sync!(query:, names: ["Staff"])

      expect(DiscourseDataExplorer::Query.find(-1).tag_names).to eq(%w[Default staff])

      DiscourseDataExplorer::QueryTag.sync!(query:, names: [])

      expect(DiscourseDataExplorer::Query.find(-1).tag_names).to eq(["Default"])
    end
  end

  describe "unscoped .find" do
    it "returns default queries" do
      expect(DiscourseDataExplorer::Query.unscoped.find(-1)).to be_present
    end
  end

  describe ".unpersisted_defaults" do
    it "assigns and filters by the default tag" do
      defaults = DiscourseDataExplorer::Query.unpersisted_defaults(tag: "Default")

      expect(defaults).to be_present
      expect(defaults.flat_map(&:tag_names).uniq).to eq(["Default"])
      expect(DiscourseDataExplorer::Query.unpersisted_defaults(tag: "Custom")).to be_empty
    end
  end
end
