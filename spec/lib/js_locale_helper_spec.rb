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

    it "formats dates with ASCII digits for ar" do
      v8_ctx.eval(File.read(VendoredAssets.path("moment/moment.js")))
      v8_ctx.eval("moment.tz = {};")
      v8_ctx.eval(JsLocaleHelper.output_locale("ar"))
      v8_ctx.eval("window._discourse_locale_data.configureMoment();")

      expect(v8_ctx.eval("moment.locale()")).to eq("ar")
      expect(v8_ctx.eval('moment("2026-05-01").format("YYYY-MM-DD")')).to eq("2026-05-01")
    end

    it "formats dates with ASCII digits for fa_IR" do
      v8_ctx.eval(File.read(VendoredAssets.path("moment/moment.js")))
      v8_ctx.eval("moment.tz = {};")
      v8_ctx.eval(JsLocaleHelper.output_locale("fa_IR"))
      v8_ctx.eval("window._discourse_locale_data.configureMoment();")

      expect(v8_ctx.eval("moment.locale()")).to eq("fa")
      expect(v8_ctx.eval('moment("2026-05-01").format("YYYY-MM-DD")')).to eq("2026-05-01")
    end
  end

  shared_examples "a supported JavaScript locale" do |locale|
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

  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ar" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "be" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "bg" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "bs_BA" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ca" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "cs" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "da" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "de" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "el" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "en" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "en_GB" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "es" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "et" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "fa_IR" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "fi" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "fr" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "gl" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "he" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "hr" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "hu" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "hy" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "id" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "it" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ja" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ko" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "lt" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "lv" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "nb_NO" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "nl" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "pl_PL" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "pt" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "pt_BR" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ro" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ru" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sk" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sl" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sq" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sr" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sv" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "sw" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "te" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "th" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "tr_TR" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ug" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "uk" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "ur" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "vi" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "zh_CN" }
  include_examples "a supported JavaScript locale",
                   LocaleSiteSetting.values.find { it[:value] == "zh_TW" }

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
