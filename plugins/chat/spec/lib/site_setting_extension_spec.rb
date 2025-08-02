# frozen_string_literal: true

RSpec.describe SiteSettingExtension do
  describe "#all_settings" do
    it "allows filtering settings by plugin via filter_plugin" do
      settings = YAML.safe_load(File.read(Rails.root.join("plugins/chat/config/settings.yml")))
      expect(
        SiteSetting
          .all_settings(include_hidden: true, filter_plugin: "chat")
          .map { |s| s[:setting] },
      ).to match_array(settings["chat"].keys.map(&:to_sym))
    end
  end
end
