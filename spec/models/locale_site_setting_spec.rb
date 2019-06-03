# frozen_string_literal: true

require 'rails_helper'

describe LocaleSiteSetting do
  def core_locales
    pattern = File.join(Rails.root, 'config', 'locales', 'client.*.yml')
    Dir.glob(pattern).map { |x| x.split('.')[-2] }
  end

  def native_locale_name(locale)
    value = LocaleSiteSetting.values.find { |v| v[:value] == locale }
    value[:name]
  end

  describe '.valid_value?' do
    it 'returns true for a locale that we have translations for' do
      expect(LocaleSiteSetting.valid_value?('en')).to eq(true)
    end

    it 'returns false for a locale that we do not have translations for' do
      expect(LocaleSiteSetting.valid_value?('swedish-chef')).to eq(false)
    end
  end

  describe '.values' do
    it 'returns all the locales that we have translations for' do
      expect(LocaleSiteSetting.values.map { |x| x[:value] }).to include(*core_locales)
    end

    it 'returns native names' do
      expect(native_locale_name('de')).to eq('Deutsch')
      expect(native_locale_name('zh_CN')).to eq('中文')
      expect(native_locale_name('zh_TW')).to eq('中文 (TW)')
    end
  end

  context 'with locales from plugin' do
    before do
      DiscoursePluginRegistry.register_locale("foo", name: "Foo", nativeName: "Native Foo")
      DiscoursePluginRegistry.register_locale("bar", name: "Bar", nativeName: "Native Bar")
      DiscoursePluginRegistry.register_locale("de", name: "Renamed German", nativeName: "Native renamed German")
      DiscoursePluginRegistry.register_locale("de_AT", name: "German (Austria)", nativeName: "Österreichisch", fallbackLocale: "de")
      DiscoursePluginRegistry.register_locale("tlh")

      # Plugins normally register a locale before LocaleSiteSetting is initialized.
      # That's not happening in tests, so we need to call reset!
      LocaleSiteSetting.reset!
    end

    after do
      DiscoursePluginRegistry.reset!
      LocaleSiteSetting.reset!
    end

    describe '.valid_value?' do
      it 'returns true for locales from core' do
        expect(LocaleSiteSetting.valid_value?('en')).to eq(true)
        expect(LocaleSiteSetting.valid_value?('de')).to eq(true)
      end

      it 'returns true for locales added by plugins' do
        expect(LocaleSiteSetting.valid_value?('foo')).to eq(true)
        expect(LocaleSiteSetting.valid_value?('bar')).to eq(true)
      end
    end

    describe '.values' do
      it 'returns native names added by plugin' do
        expect(native_locale_name('foo')).to eq('Native Foo')
        expect(native_locale_name('bar')).to eq('Native Bar')
      end

      it 'does not allow plugins to override native names that exist in core' do
        expect(native_locale_name('de')).to eq('Deutsch')
      end

      it 'returns the language code when no nativeName is set' do
        expect(native_locale_name('tlh')).to eq('tlh')
      end
    end

    describe '.fallback_locale' do
      it 'returns the fallback locale registered by plugin' do
        expect(LocaleSiteSetting.fallback_locale('de_AT')).to eq(:de)
        expect(LocaleSiteSetting.fallback_locale(:de_AT)).to eq(:de)
      end

      it 'returns nothing when no fallback locale was registered' do
        expect(LocaleSiteSetting.fallback_locale('foo')).to be_nil
      end

      it 'returns English for English (United States)' do
        expect(LocaleSiteSetting.fallback_locale('en_US')).to eq(:en)
      end
    end
  end

  describe '.fallback_locale' do
    it 'returns English for English (United States)' do
      expect(LocaleSiteSetting.fallback_locale('en_US')).to eq(:en)
    end
  end
end
