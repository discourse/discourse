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

    it "can have min or max value" do
      int_setting = find_by_name(:integer_setting_02)
      expect { int_setting.value = 0 }.to raise_error(Discourse::InvalidParameters)
      expect { int_setting.value = 61 }.to raise_error(Discourse::InvalidParameters)

      int_setting.value = 60
      expect(int_setting.value).to eq(60)

      int_setting.value = 1
      expect(int_setting.value).to eq(1)
    end
  end

  context "Float" do
    it "is always a float" do
      float_setting = find_by_name(:float_setting)
      float_setting.value = 1.615
      expect(float_setting.value).to eq(1.615)

      float_setting.value = "3.1415"
      expect(float_setting.value).to eq(3.1415)

      float_setting.value = 10
      expect(float_setting.value).to eq(10)
    end

    it "can have min or max value" do
      float_setting = find_by_name(:float_setting)
      expect { float_setting.value = 1.4 }.to raise_error(Discourse::InvalidParameters)
      expect { float_setting.value = 10.01 }.to raise_error(Discourse::InvalidParameters)
      expect { float_setting.value = "text" }.to raise_error(Discourse::InvalidParameters)

      float_setting.value = 9.521
      expect(float_setting.value).to eq(9.521)
    end
  end

  context "String" do
    it "can have min or max length" do
      string_setting = find_by_name(:string_setting_02)
      expect { string_setting.value = "a" }.to raise_error(Discourse::InvalidParameters)

      string_setting.value = "ab"
      expect(string_setting.value).to eq("ab")

      string_setting.value = "ab" * 10
      expect(string_setting.value).to eq("ab" * 10)

      expect { string_setting.value = ("a" * 21) }.to raise_error(Discourse::InvalidParameters)
    end
  end
end
