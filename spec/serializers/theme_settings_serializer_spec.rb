# frozen_string_literal: true

RSpec.describe ThemeSettingsSerializer do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  describe "#objects_schema" do
    it "should include the attribute when theme setting is typed objects" do
      payload = ThemeSettingsSerializer.new(theme_setting[:objects_setting]).as_json

      expect(payload[:theme_settings][:objects_schema][:name]).to eq("section")
    end
  end
end
