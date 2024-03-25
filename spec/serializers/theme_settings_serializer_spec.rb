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
end
