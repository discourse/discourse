# frozen_string_literal: true

require "mini_racer"

RSpec.describe JsLocaleHelper do
  let(:v8_ctx) do
    node_modules = "#{Rails.root}/node_modules/"
    transpiler = DiscourseJsProcessor::Transpiler.new
    ctx = MiniRacer::Context.new
    ctx.load("#{node_modules}/loader.js/dist/loader/loader.js")
    ctx.eval("var window = globalThis;")
    {
      "@messageformat/runtime/messages": "#{node_modules}/@messageformat/runtime/esm/messages.js",
      "@messageformat/runtime": "#{node_modules}/@messageformat/runtime/esm/runtime.js",
      "@messageformat/runtime/lib/cardinals":
        "#{node_modules}/@messageformat/runtime/esm/cardinals.js",
      "make-plural/cardinals": "#{node_modules}/make-plural/cardinals.mjs",
      "discourse-i18n": "#{Rails.root}/app/assets/javascripts/discourse-i18n/src/index.js",
    }.each do |module_name, path|
      ctx.eval(transpiler.perform(File.read(path), "", module_name.to_s))
    end
    ctx.eval <<~JS
      define("discourse/loader-shims", () => {})
    JS
    # As there are circular references in the return value, this raises an
    # error if we let MiniRacer try to convert the value to JSON. Forcing
    # returning `null` from `#eval` will prevent that.
    ctx.eval("#{File.read("#{Rails.root}/app/assets/javascripts/locales/i18n.js")};null")
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
    let(:output) { described_class.output_MF(locale).gsub(/^import.*$/, "") }
    let(:generated_locales) { v8_ctx.eval("Object.keys(I18n._mfMessages._data)") }
    let(:translated_message) do
      v8_ctx.eval("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})")
    end
    let!(:overriden_translation) do
      Fabricate(
        :translation_override,
        translation_key: "admin_js.admin.user.penalty_history_MF",
        value: "OVERRIDEN",
      )
    end

    before { v8_ctx.eval(output) }

    context "when locale is 'en'" do
      let(:locale) { "en" }

      it "generates messages for the 'en' locale only" do
        expect(generated_locales).to eq %w[en]
      end

      it "translates messages properly" do
        expect(
          translated_message,
        ).to eq "This topic has 3 replies with a very high like to post ratio\n"
      end

      context "when the translation is overriden" do
        let(:translated_message) do
          v8_ctx.eval(
            "I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 })",
          )
        end

        it "returns the overriden translation" do
          expect(translated_message).to eq "OVERRIDEN"
        end
      end
    end

    context "when locale is not 'en'" do
      let(:locale) { "fr" }

      it "generates messages for the current locale and uses 'en' as fallback" do
        expect(generated_locales).to match(%w[fr en])
      end

      it "translates messages properly" do
        expect(
          translated_message,
        ).to eq "Ce sujet comprend 3 réponses avec un taux très élevé de « J'aime » par message\n"
      end

      context "when a translation is missing" do
        before { v8_ctx.eval("delete I18n._mfMessages._data.fr.posts_likes_MF") }

        it "returns the fallback translation" do
          expect(
            translated_message,
          ).to eq "This topic has 3 replies with a very high like to post ratio\n"
        end

        context "when the fallback translation is overriden" do
          let(:translated_message) do
            v8_ctx.eval(
              "I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 })",
            )
          end

          before do
            v8_ctx.eval("delete I18n._mfMessages._data.fr['admin.user.penalty_history_MF']")
          end

          it "returns the overriden fallback translation" do
            expect(translated_message).to eq "OVERRIDEN"
          end
        end
      end
    end
  end
end
