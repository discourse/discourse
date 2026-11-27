# frozen_string_literal: true

RSpec.describe PopularThemes do
  describe ".all" do
    it "describes every entry in the current locale" do
      expect(described_class.all.map { |entry| entry[:description] }).to all(
        be_present.and(satisfy { |description| !description.include?("translation missing") }),
      )
    end
  end

  describe ".themes" do
    it "leaves out components" do
      expect(described_class.themes.map { |entry| entry[:id] }).to include("graceful").and exclude(
              "brand_header",
              "concord",
            )
    end
  end

  describe ".find_by_remote_url" do
    it "matches URLs ending in .git or a slash, in any case" do
      expect(
        described_class.find_by_remote_url("https://github.com/discourse/DiscoTOC.git"),
      ).to include(id: "table_of_contents")
      expect(
        described_class.find_by_remote_url("https://github.com/Discourse/graceful/"),
      ).to include(id: "graceful")
      expect(described_class.find_by_remote_url("https://example.com/theme")).to be_nil
      expect(described_class.find_by_remote_url(nil)).to be_nil
    end
  end
end
