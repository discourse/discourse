# frozen_string_literal: true

require "mini_racer"

RSpec.describe JsLocaleHelper do
  let(:v8_ctx) do
    node_modules = "#{Rails.root}/node_modules/"

    transpiler = DiscourseJsProcessor::Transpiler.new
    discourse_i18n =
      transpiler.perform(
        File.read("#{Rails.root}/app/assets/javascripts/discourse-i18n/src/index.js"),
        "app/assets/javascripts/discourse",
        "discourse-i18n",
      )

    ctx = MiniRacer::Context.new
    ctx.load("#{node_modules}/loader.js/dist/loader/loader.js")
    ctx.eval("var window = globalThis;")
    ctx.eval(discourse_i18n)
    ctx.eval <<~JS
      define("discourse/loader-shims", () => {})
    JS
    ctx.load("#{Rails.root}/app/assets/javascripts/locales/i18n.js")
    ctx
  end

  module StubLoadTranslations
    def set_translations(locale, translations)
      @loaded_translations ||= HashWithIndifferentAccess.new
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

  it "performs fallbacks to English if a translation is not available" do
    JsLocaleHelper.set_translations(
      "en",
      "en" => {
        "js" => {
          "only_english" => "1-en",
          "english_and_site" => "3-en",
          "english_and_user" => "5-en",
          "all_three" => "7-en",
        },
      },
    )

    JsLocaleHelper.set_translations(
      "ru",
      "ru" => {
        "js" => {
          "only_site" => "2-ru",
          "english_and_site" => "3-ru",
          "site_and_user" => "6-ru",
          "all_three" => "7-ru",
        },
      },
    )

    JsLocaleHelper.set_translations(
      "uk",
      "uk" => {
        "js" => {
          "only_user" => "4-uk",
          "english_and_user" => "5-uk",
          "site_and_user" => "6-uk",
          "all_three" => "7-uk",
        },
      },
    )

    expected = {
      "none" => "[uk.js.none]",
      "only_english" => "1-en",
      "only_site" => "[uk.js.only_site]",
      "english_and_site" => "3-en",
      "only_user" => "4-uk",
      "english_and_user" => "5-uk",
      "site_and_user" => "6-uk",
      "all_three" => "7-uk",
    }

    SiteSetting.default_locale = "ru"
    I18n.locale = :uk

    v8_ctx.eval(JsLocaleHelper.output_locale(I18n.locale))
    v8_ctx.eval('I18n.defaultLocale = "ru";')

    expect(v8_ctx.eval("I18n.translations").keys).to contain_exactly("uk", "en")
    expect(v8_ctx.eval("I18n.translations.uk.js").keys).to contain_exactly(
      "all_three",
      "english_and_user",
      "only_user",
      "site_and_user",
    )
    expect(v8_ctx.eval("I18n.translations.en.js").keys).to contain_exactly(
      "only_english",
      "english_and_site",
    )

    expected.each do |key, expect|
      expect(v8_ctx.eval("I18n.t(#{"js.#{key}".inspect})")).to eq(expect)
    end
  end

  LocaleSiteSetting.values.each do |locale|
    it "generates valid date helpers for #{locale[:value]} locale" do
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
  end

  describe ".output_MF" do
    subject(:output) { described_class.output_MF(locale) }

    context "when locale is 'en'" do
      let(:locale) { "en" }

      it "outputs message format messages for 'en'" do
        expect(output).to match(/en:.*_MF/m)
      end
    end

    context "when locale is not 'en'" do
      let(:locale) { "fr" }

      it "outputs message format messages for this locale" do
        expect(output).to match(/fr:.*_MF/m)
      end

      it "outputs a fallback locale too" do
        expect(output).to match(/en:.*_MF/m)
      end
    end
  end
end
