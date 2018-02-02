require 'rails_helper'
require 'theme_settings_manager'

describe ThemeSettingsManager do

  let(:theme_settings) do
    theme = Theme.create!(name: "awesome theme", user_id: -1)
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/valid_settings.yaml")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  def find_by_name(name)
    theme_settings.find { |setting| setting.name == name }
  end

  context "Enum" do
    it "only accepts values from its choices" do
      enum_setting = find_by_name(:enum_setting)
      expect { enum_setting.value = "trust level 2" }.to raise_error(Discourse::InvalidParameters)
      expect { enum_setting.value = "trust level 0" }.not_to raise_error

      enum_setting = find_by_name(:enum_setting_02)
      expect { enum_setting.value = "10" }.not_to raise_error

      enum_setting = find_by_name(:enum_setting_03)
      expect { enum_setting.value = "10" }.not_to raise_error
      expect { enum_setting.value = 1 }.not_to raise_error
      expect { enum_setting.value = 15 }.to raise_error(Discourse::InvalidParameters)
    end
  end

  context "Bool" do
    it "is either true or false" do
      bool_setting = find_by_name(:boolean_setting)
      expect(bool_setting.value).to eq(true) # default

      bool_setting.value = "true"
      expect(bool_setting.value).to eq(true)

      bool_setting.value = "falsse" # intentionally misspelled
      expect(bool_setting.value).to eq(false)

      bool_setting.value = true
      expect(bool_setting.value).to eq(true)
    end
  end

  context "Integer" do
    it "is always an integer" do
      int_setting = find_by_name(:integer_setting)
      int_setting.value = 1.6
      expect(int_setting.value).to eq(1)

      int_setting.value = "4.3"
      expect(int_setting.value).to eq(4)

      int_setting.value = "10"
      expect(int_setting.value).to eq(10)

      int_setting.value = "text"
      expect(int_setting.value).to eq(0)
    end
  end
end
