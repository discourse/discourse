# frozen_string_literal: true

RSpec.describe "Locale choice", type: :system do
  it "loads english locale successfully" do
    visit "/"
    expect(page).to have_css("html[lang='en']")
    expect(page).to have_css(
      "#navigation-bar .categories",
      text: I18n.t("js.filters.categories.title", locale: :en),
    )
    expect(page.evaluate_script("moment.locale()")).to eq("en")
  end

  it "loads french locale successfully" do
    SiteSetting.default_locale = "fr"
    visit "/"
    expect(page).to have_css("html[lang='fr']")
    expect(page).to have_css(
      "#navigation-bar .categories",
      text: I18n.t("js.filters.categories.title", locale: :fr),
    )
    expect(page.evaluate_script("moment.locale()")).to eq("fr")
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

      visit "/"
      expect(page).to have_css("#site-logo")

      expect(page.evaluate_script("I18n.locale")).to eq("uk")
      expect(page.evaluate_script("Object.keys(I18n.translations)")).to contain_exactly("uk", "en")

      expect(page.evaluate_script("I18n.translations.uk.js").keys).to contain_exactly(
        "all_three",
        "english_and_user",
        "only_user",
        "site_and_user",
      )
      expect(page.evaluate_script("I18n.translations.en.js").keys).to contain_exactly(
        "only_english",
        "english_and_site",
      )

      expected.each do |key, expect|
        expect(page.evaluate_script("I18n.t(#{"js.#{key}".inspect})")).to eq(expect)
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
    end

    it "works for english" do
      SiteSetting.default_locale = "en"
      visit "/"
      expect(page).to have_css("#site-logo")

      expect(page.evaluate_script("Object.keys(I18n._mfMessages._data)")).to eq(["en"])
      expect(
        page.evaluate_script("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})"),
      ).to eq("3 replies, very high like to post ratio, jump to the first or last post…\n")

      expect(
        page.evaluate_script(
          "I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 })",
        ),
      ).to eq("OVERRIDEN")
    end

    it "works for other locales" do
      SiteSetting.default_locale = "fr"
      visit "/"
      expect(page).to have_css("#site-logo")

      expect(page.evaluate_script("Object.keys(I18n._mfMessages._data)")).to contain_exactly(
        "en",
        "fr",
      )

      expect(
        page.evaluate_script("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})"),
      ).to eq(
        "3 réponses, avec un taux très élevé de « J'aime » par publication, accéder à la première ou dernière publication...\n",
      )

      page.evaluate_script("delete I18n._mfMessages._data.fr.posts_likes_MF")

      expect(
        page.evaluate_script("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})"),
      ).to eq("3 replies, very high like to post ratio, jump to the first or last post…\n")

      expect(
        page.evaluate_script(
          "I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 })",
        ),
      ).to eq(
        "Au cours des 6 derniers mois, cet utilisateur a été <b>suspendu 3 fois</b> et <b>mis en sourdine 2 fois</b>.",
      )

      page.evaluate_script("delete I18n._mfMessages._data.fr['admin.user.penalty_history_MF']")

      expect(
        page.evaluate_script(
          "I18n._mfMessages.get('admin.user.penalty_history_MF', { SUSPENDED: 3, SILENCED: 2 })",
        ),
      ).to eq("OVERRIDEN")
    end

    it "does not throw error for invalid plural keys" do
      SiteSetting.default_locale = "ja"
      visit "/"
      expect(page).to have_css("#site-logo")

      expect(page.evaluate_script("Object.keys(I18n._mfMessages._data)")).to contain_exactly(
        "ja",
        "en",
      )
      expect(
        page.evaluate_script("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})"),
      ).to eq("返信 3 件、")
    end

    it "does not throw error for malformed messages" do
      SiteSetting.default_locale = "zh_TW"
      visit "/"
      expect(page).to have_css("#site-logo")

      expect(page.evaluate_script("Object.keys(I18n._mfMessages._data)").length).to eq(0)
      expect(
        page.evaluate_script("I18n._mfMessages.get('posts_likes_MF', {count: 3, ratio: 'med'})"),
      ).to eq("posts_likes_MF")
    end
  end
end
