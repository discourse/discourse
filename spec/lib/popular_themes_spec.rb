# frozen_string_literal: true

RSpec.describe PopularThemes do
  describe ".all" do
    it "describes every entry in the current locale" do
      expect(described_class.all.map { |entry| entry[:description] }).to all(
        be_present.and(satisfy { |description| !description.include?("translation missing") }),
      )
    end

    it "offers Concord, with its screenshot under the base path" do
      set_subfolder "/forum"

      concord = described_class.all.find { |entry| entry[:id] == "concord" }

      expect(concord).to include(
        name: "Concord",
        remote_url: DesignWizard::Themes::CONCORD[:remote_url],
        description: I18n.t(DesignWizard::Themes::CONCORD[:description_key]),
        component: false,
      )
      expect(concord[:screenshot_url]).to start_with("/forum/images/")
    end
  end

  describe ".themes" do
    it "leaves out components" do
      expect(described_class.themes.map { |entry| entry[:id] }).to include(
        "graceful",
        "concord",
      ).and exclude("brand_header")
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
