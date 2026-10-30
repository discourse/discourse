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

  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ar" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "be" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "bg" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "bs_BA" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ca" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "cs" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "da" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "de" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "el" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "en" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "en_GB" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "es" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "et" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "fa_IR" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "fi" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "fr" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "gl" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "he" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "hr" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "hu" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "hy" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "id" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "it" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ja" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ko" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "lt" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "lv" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "nb_NO" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "nl" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "pl_PL" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "pt" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "pt_BR" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ro" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ru" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sk" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sl" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sq" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sr" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sv" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "sw" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "te" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "th" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "tr_TR" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ug" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "uk" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "ur" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "vi" }
  it_behaves_like "a supported JavaScript locale",
                  LocaleSiteSetting.values.find { it[:value] == "zh_CN" }
  it_behaves_like "a supported JavaScript locale",
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
