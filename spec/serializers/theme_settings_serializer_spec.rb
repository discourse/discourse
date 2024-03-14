# frozen_string_literal: true

RSpec.describe ThemeSettingsSerializer do
  fab!(:theme)

  let(:objects_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings[:objects_setting]
  end

  describe "#objects_schema" do
    before { SiteSetting.experimental_objects_type_for_theme_settings = true }

    it "should include the attribute when theme setting is typed objects" do
      payload = ThemeSettingsSerializer.new(objects_setting).as_json

      expect(payload[:theme_settings][:objects_schema][:name]).to eq("section")
    end
  end

  describe "#objects_schema_property_descriptions" do
    let(:objects_setting_locale) do
      theme.set_field(
        target: :translations,
        name: "en",
        value: File.read("#{Rails.root}/spec/fixtures/theme_locales/objects_settings/en.yaml"),
      )

      theme.save!
    end

    before { SiteSetting.experimental_objects_type_for_theme_settings = true }

    it "should not include the attribute when theme setting is not typed objects" do
      yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/valid_settings.yaml")
      theme.set_field(target: :settings, name: "yaml", value: yaml)
      theme.save!

      payload = ThemeSettingsSerializer.new(theme.settings[:string_setting]).as_json

      expect(payload[:theme_settings][:objects_schema_property_descriptions]).to be_nil
    end

    it "should include the attribute when theme setting is of typed objects" do
      objects_setting_locale
      objects_setting

      payload = ThemeSettingsSerializer.new(objects_setting).as_json

      expect(payload[:theme_settings][:objects_schema_property_descriptions]).to eq(
        {
          "links.name" => "Name of the link",
          "links.url" => "URL of the link",
          "name" => "Section Name",
        },
      )
    end
  end
end
