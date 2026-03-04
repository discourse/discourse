# frozen_string_literal: true

RSpec.describe JsLocaleHelper do
  let(:v8_ctx) do
    ctx = MiniRacer::Context.new
    ctx.eval("var window = globalThis;")
    ctx
  end

  module StubLoadTranslations
    def set_translations(locale, translations)
      @loaded_translations ||= ActiveSupport::HashWithIndifferentAccess.new
      @loaded_translations[locale] = translations
    end

    def clear_cache!
      @loaded_translations = nil
      @loaded_merges = nil
    end
  end

  JsLocaleHelper.extend StubLoadTranslations

  before { JsLocaleHelper.clear_cache! }
  after { JsLocaleHelper.clear_cache! }

  describe "#output_locale" do
    it "doesn't change the cached translations hash" do
      I18n.locale = :fr
      expect(JsLocaleHelper.output_locale("fr").length).to be > 0
      expect(JsLocaleHelper.translations_for("fr")["fr"].keys).to contain_exactly(
        "js",
        "admin_js",
        "wizard_js",
      )
    end
  end

  LocaleSiteSetting.values.each do |locale|
    it "generates valid JS for #{locale[:value]} locale" do
      js = JsLocaleHelper.output_locale(locale[:value])
      v8_ctx.eval(js)
    end

    it "finds moment.js locale file for #{locale[:value]}" do
      content = JsLocaleHelper.moment_locale(locale[:value])

      if (locale[:value] == SiteSettings::DefaultsProvider::DEFAULT_LOCALE)
        expect(content).to eq("")
      else
        expect(content).to_not eq("")
      end
    end

    it "generates valid MF locales for the '#{locale[:value]}' locale" do
      expect(described_class.output_MF(locale[:value])).not_to match(/Failed to compile/)
    end
  end

  describe ".output_client_overrides" do
    subject(:client_overrides) { described_class.output_client_overrides("en") }

    before do
      Fabricate(
        :translation_override,
        locale: "en",
        translation_key: "js.user.preferences.title",
        value: "SHOULD_SHOW",
      )
      Fabricate(
        :translation_override,
        locale: "en",
        translation_key: "js.user.preferences",
        value: "SHOULD_NOT_SHOW",
        status: "deprecated",
      )
    end

    it "does not output deprecated translation overrides" do
      expect(client_overrides).to include("SHOULD_SHOW")
      expect(client_overrides).not_to include("SHOULD_NOT_SHOW")
    end
  end
end
