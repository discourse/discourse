require 'rails_helper'

RSpec.describe ThemeSerializer do
  describe "load theme settings" do
    it 'should add error message when having invalid format' do
      theme = Fabricate(:theme)
      Theme.any_instance.stubs(:settings).raises(ThemeSettingsParser::InvalidYaml, I18n.t("themes.settings_errors.invalid_yaml"))
      errors = ThemeSerializer.new(theme).as_json[:theme][:errors]
      expect(errors.count).to eq(1)
      expect(errors[0]).to eq(I18n.t("themes.settings_errors.invalid_yaml"))
    end
  end
end
