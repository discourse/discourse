# frozen_string_literal: true

RSpec.describe "Locale choice" do
  it "loads english locale successfully" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("html[lang='en']").filter(visible: true)).not_to have_count(0)
    expect(
      browser_root.locator("#navigation-bar .categories").filter(visible: true),
    ).to contain_text(
      [browser_text_pattern(I18n.t("js.filters.categories.title", locale: :en))],
      useInnerText: true,
    )
    expect(browser_page.evaluate("function(arguments) { return moment.locale() }", arg: [])).to eq(
      "en",
    )
    expect(
      browser_page.evaluate("function(arguments) { return I18n._mfMessages.locale }", arg: []),
    ).to eq("en")
  end

  it "loads french locale successfully" do
    SiteSetting.default_locale = "fr"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("html[lang='fr']").filter(visible: true)).not_to have_count(0)
    expect(
      browser_root.locator("#navigation-bar .categories").filter(visible: true),
    ).to contain_text(
      [browser_text_pattern(I18n.t("js.filters.categories.title", locale: :fr))],
      useInnerText: true,
    )
    expect(browser_page.evaluate("function(arguments) { return moment.locale() }", arg: [])).to eq(
      "fr",
    )
    expect(
      browser_page.evaluate("function(arguments) { return I18n._mfMessages.locale }", arg: []),
    ).to eq("fr")
  end

  it "loads polish locale successfully" do
    SiteSetting.default_locale = "pl_PL"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("html[lang='pl-PL']").filter(visible: true)).not_to have_count(0)
    expect(
      browser_root.locator("#navigation-bar .categories").filter(visible: true),
    ).to contain_text(
      [browser_text_pattern(I18n.t("js.filters.categories.title", locale: :pl_PL))],
      useInnerText: true,
    )
    expect(browser_page.evaluate("function(arguments) { return moment.locale() }", arg: [])).to eq(
      "pl",
    )
    expect(
      browser_page.evaluate("function(arguments) { return I18n._mfMessages.locale }", arg: []),
    ).to eq("pl-PL")
  end

  context "with test locales" do
    before do
      JsLocaleHelper.clear_cache!

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
    end

    after { JsLocaleHelper.clear_cache! }

    it "handles fallback correctly" do
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

      SiteSetting.default_locale = "uk"

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page.evaluate("function(arguments) { return I18n.locale }", arg: [])).to eq(
        "uk",
      )
      expect(
        browser_page.evaluate(
          "function(arguments) { return Object.keys(I18n.translations) }",
          arg: [],
        ),
      ).to contain_exactly("uk", "en")

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n.translations.uk.js }",
          arg: [],
        ).keys,
      ).to contain_exactly("all_three", "english_and_user", "only_user", "site_and_user")
      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n.translations.en.js }",
          arg: [],
        ).keys,
      ).to contain_exactly("only_english", "english_and_site")

      expected.each do |key, expect|
        expect(
          browser_page.evaluate(
            "function(arguments) { return #{"I18n.t(#{"js.#{key}".inspect})"} }",
            arg: [],
          ),
        ).to eq(expect)
      end
    end
  end

  context "with messageformat overrides" do
    fab!(:overriden_translation_en) do
      Fabricate(
        :translation_override,
        translation_key: "admin_js.admin.user.penalty_history_MF",
        value: "OVERRIDEN",
      )
    end
    fab!(:overriden_translation_ja) do
      Fabricate(:translation_override, locale: "ja", translation_key: "js.posts_likes_MF")
    end
    fab!(:overriden_translation_zh_tw) do
      Fabricate(:translation_override, locale: "zh_TW", translation_key: "js.posts_likes_MF")
    end

    before do
      overriden_translation_ja.update_columns(
        value: "{ count, plural, one {返信 # 件、} other {返信 # 件、} }",
      )
      overriden_translation_zh_tw.update_columns(value: "{ count, plural, ")

      # update_columns skips the model layer, so burst the bundle digest cache
      # like TranslationOverride.upsert! would have.
      ExtraLocalesController.clear_cache!
    end

    it "works for english" do
      SiteSetting.default_locale = "en"
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_page.evaluate(
          "function(arguments) { return Object.keys(I18n._mfMessages._data) }",
          arg: [],
        ),
      ).to eq(["en"])
      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'}) }",
          arg: [],
        ),
      ).to eq("3 replies, very high like to post ratio, jump to the first or last post…\n")

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 }) }",
          arg: [],
        ),
      ).to eq("OVERRIDEN")
    end

    it "works for other locales" do
      SiteSetting.default_locale = "fr"
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_page.evaluate(
          "function(arguments) { return Object.keys(I18n._mfMessages._data) }",
          arg: [],
        ),
      ).to contain_exactly("en", "fr")

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'}) }",
          arg: [],
        ),
      ).to eq(
        "3 réponses, avec un taux très élevé de « J'aime » par publication, accéder à la première ou dernière publication...\n",
      )

      browser_page.evaluate(
        "function(arguments) { return delete I18n._mfMessages._data.fr.posts_likes_MF }",
        arg: [],
      )

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'}) }",
          arg: [],
        ),
      ).to eq("3 replies, very high like to post ratio, jump to the first or last post…\n")

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 }) }",
          arg: [],
        ),
      ).to eq(
        "Au cours des 6 derniers mois, cet utilisateur a été <b>suspendu 3 fois</b> et <b>mis en sourdine 2 fois</b>.",
      )

      browser_page.evaluate(
        "function(arguments) { return delete I18n._mfMessages._data.fr['admin.user.penalty_history_MF'] }",
        arg: [],
      )

      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 }) }",
          arg: [],
        ),
      ).to eq("OVERRIDEN")
    end

    it "does not throw error for invalid plural keys" do
      SiteSetting.default_locale = "ja"
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_page.evaluate(
          "function(arguments) { return Object.keys(I18n._mfMessages._data) }",
          arg: [],
        ),
      ).to contain_exactly("ja", "en")
      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'}) }",
          arg: [],
        ),
      ).to eq("返信 3 件、")
    end

    it "does not throw error for malformed messages" do
      SiteSetting.default_locale = "zh_TW"

      # Suppress the expected error from the intentionally malformed zh_TW MF string
      silence_stdout do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      expect(
        browser_page.evaluate(
          "function(arguments) { return Object.keys(I18n._mfMessages._data) }",
          arg: [],
        ).length,
      ).to eq(0)
      expect(
        browser_page.evaluate(
          "function(arguments) { return I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'}) }",
          arg: [],
        ),
      ).to eq("posts_likes_MF")
    end
  end
end
