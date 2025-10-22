# frozen_string_literal: true

RSpec.describe LocaleSiteSetting do
  def core_locales
    pattern = File.join(Rails.root, "config", "locales", "client.*.yml")
    Dir.glob(pattern).map { |x| x.split(".")[-2] }
  end

  def native_locale_name(locale)
    value = LocaleSiteSetting.values.find { |v| v[:value] == locale }
    value[:native_name]
  end

  describe ".valid_value?" do
    it "returns true for a locale that we have translations for" do
      expect(LocaleSiteSetting.valid_value?("en")).to eq(true)
    end

    it "returns false for a locale that we do not have translations for" do
      expect(LocaleSiteSetting.valid_value?("swedish-chef")).to eq(false)
    end
  end

  describe ".values" do
    it "returns all the locales that we have translations for" do
      expect(LocaleSiteSetting.values.map { |x| x[:value] }).to include(*core_locales)
    end

    it "returns native names" do
      expect(native_locale_name("de")).to eq("Deutsch")
      expect(native_locale_name("zh_CN")).to eq("简体中文")
      expect(native_locale_name("zh_TW")).to eq("繁體中文")
    end
  end

  context "with locales from plugin" do
    before do
      DiscoursePluginRegistry.register_locale("foo", name: "Foo", nativeName: "Native Foo")
      DiscoursePluginRegistry.register_locale("bar", name: "Bar", nativeName: "Native Bar")
      DiscoursePluginRegistry.register_locale(
        "de",
        name: "Renamed German",
        nativeName: "Native renamed German",
      )
      DiscoursePluginRegistry.register_locale(
        "de_AT",
        name: "German (Austria)",
        nativeName: "Österreichisch",
        fallbackLocale: "de",
      )
      DiscoursePluginRegistry.register_locale("tlh")

      # Plugins normally register a locale before LocaleSiteSetting is initialized.
      # That's not happening in tests, so we need to call reset!
      LocaleSiteSetting.reset!
    end

    after do
      DiscoursePluginRegistry.unregister_locale("foo")
      DiscoursePluginRegistry.unregister_locale("bar")
      DiscoursePluginRegistry.unregister_locale("de")
      DiscoursePluginRegistry.unregister_locale("de_AT")
      DiscoursePluginRegistry.unregister_locale("tlh")
      LocaleSiteSetting.reset!
    end

    describe ".valid_value?" do
      it "returns true for locales from core" do
        expect(LocaleSiteSetting.valid_value?("en")).to eq(true)
        expect(LocaleSiteSetting.valid_value?("de")).to eq(true)
        expect(LocaleSiteSetting.valid_value?("en|de")).to eq(true)
      end

      it "returns true for locales added by plugins" do
        expect(LocaleSiteSetting.valid_value?("foo")).to eq(true)
        expect(LocaleSiteSetting.valid_value?("bar")).to eq(true)
      end
    end

    describe ".values" do
      it "returns native names added by plugin" do
        expect(native_locale_name("foo")).to eq("Native Foo")
        expect(native_locale_name("bar")).to eq("Native Bar")
      end

      it "does not allow plugins to override native names that exist in core" do
        expect(native_locale_name("de")).to eq("Deutsch")
      end

      it "returns nothing when no nativeName is set" do
        expect(native_locale_name("tlh")).to eq(nil)
      end
    end

    describe ".fallback_locale" do
      it "returns the fallback locale registered by plugin" do
        expect(LocaleSiteSetting.fallback_locale("de_AT")).to eq(:de)
        expect(LocaleSiteSetting.fallback_locale(:de_AT)).to eq(:de)
      end

      it "returns nothing when no fallback locale was registered" do
        expect(LocaleSiteSetting.fallback_locale("foo")).to be_nil
      end

      it "returns English for English (UK)" do
        expect(LocaleSiteSetting.fallback_locale("en_GB")).to eq(:en)
      end
    end
  end

  describe ".fallback_locale" do
    it "returns English for English (UK)" do
      expect(LocaleSiteSetting.fallback_locale("en_GB")).to eq(:en)
    end
  end

  describe ".supported_locales" do
    it "has a language name for each supported locale" do
      LocaleSiteSetting.supported_locales.each do |locale|
        expect(LocaleSiteSetting.language_names[locale]).to be_present
      end
    end
  end
end
