# frozen_string_literal: true

RSpec.describe ThemeObjectsSettingMetadataSerializer do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  before { SiteSetting.experimental_objects_type_for_theme_settings = true }

  describe "#property_descriptions" do
    let(:objects_setting_locale) do
      theme.set_field(
        target: :translations,
        name: "en",
        value: File.read("#{Rails.root}/spec/fixtures/theme_locales/objects_settings/en.yaml"),
      )

      theme.save!
    end

    it "should return a hash of the settings property descriptions" do
      objects_setting_locale

      payload = described_class.new(theme_setting[:objects_setting], root: false).as_json

      expect(payload[:property_descriptions]).to eq(
        {
          "links.name" => "Name of the link",
          "links.url" => "URL of the link",
          "name" => "Section Name",
        },
      )
    end
  end
end
