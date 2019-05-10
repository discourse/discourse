# frozen_string_literal: true

require 'rails_helper'
require 'theme_settings_parser'

describe ThemeSettingsParser do
  after(:all) do
    ThemeField.destroy_all
  end

  def types
    ThemeSetting.types
  end

  class Loader
    def initialize
      @settings ||= []
      load_settings
    end

    def load_settings
      yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/valid_settings.yaml")
      field = ThemeField.create!(theme_id: 1, target_id: 3, name: "yaml", value: yaml)

      ThemeSettingsParser.new(field).load do |name, default, type, opts|
        @settings << setting(name, default, type, opts)
      end
    end

    def setting(name, default, type, opts = {})
      { name: name, default: default, type: type, opts: opts }
    end

    def find_by_name(name)
      @settings.find { |setting| setting[:name] == name }
    end
  end

  let(:loader) { Loader.new }

  it "guesses types correctly" do
    expect(loader.find_by_name(:boolean_setting)[:type]).to     eq(types[:bool])
    expect(loader.find_by_name(:boolean_setting_02)[:type]).to  eq(types[:bool])
    expect(loader.find_by_name(:string_setting)[:type]).to      eq(types[:string])
    expect(loader.find_by_name(:integer_setting)[:type]).to     eq(types[:integer])
    expect(loader.find_by_name(:integer_setting_03)[:type]).to  eq(types[:integer])
    expect(loader.find_by_name(:float_setting)[:type]).to       eq(types[:float])
    expect(loader.find_by_name(:list_setting)[:type]).to        eq(types[:list])
    expect(loader.find_by_name(:enum_setting)[:type]).to        eq(types[:enum])
  end

  context "description locale" do
    it "favors I18n.locale" do
      I18n.locale = :ar
      SiteSetting.default_locale = "en"
      expect(loader.find_by_name(:enum_setting_02)[:opts][:description]).to eq("Arabic text")
    end

    it "uses SiteSetting.default_locale if I18n.locale isn't supported" do
      I18n.locale = :en
      SiteSetting.default_locale = "es"
      expect(loader.find_by_name(:integer_setting_02)[:opts][:description]).to eq("Spanish text")
    end

    it "finds the first supported locale and uses it as a last resort" do
      I18n.locale = :de
      SiteSetting.default_locale = "it"
      expect(loader.find_by_name(:integer_setting_02)[:opts][:description]).to eq("French text")
    end

    it "doesn't set locale if no supported locale is provided" do
      expect(loader.find_by_name(:integer_setting_03)[:opts][:description]).to be_nil
    end
  end

  context "enum setting" do
    it "should never have less than 1 choices" do
      choices = loader.find_by_name(:enum_setting)[:opts][:choices]
      expect(choices.class).to eq(Array)
      expect(choices.length).to eq(3)

      choices = loader.find_by_name(:enum_setting_02)[:opts][:choices]
      expect(choices.class).to eq(Array)
      expect(choices.length).to eq(1)
    end
  end

  context "list setting" do
    it "supports list type" do
      list_type = loader.find_by_name(:compact_list_setting)[:opts][:list_type]
      expect(list_type).to eq("compact")
    end
  end
end
