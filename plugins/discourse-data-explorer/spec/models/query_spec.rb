# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Query do
  before { SiteSetting.data_explorer_enabled = true }

  describe ".find" do
    it "returns default queries" do
      expect(DiscourseDataExplorer::Query.find(-1)).to be_present
    end
  end

  describe "unscoped .find" do
    it "returns default queries" do
      expect(DiscourseDataExplorer::Query.unscoped.find(-1)).to be_present
    end
  end
end
