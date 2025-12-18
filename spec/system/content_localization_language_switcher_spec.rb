# frozen_string_literal: true

describe "Content localization language switcher", type: :system do
  SWITCHER_SELECTOR = "button[data-identifier='language-switcher']"
  TOGGLE_LOCALIZE_BUTTON_SELECTOR = "button.btn-toggle-localized-content"

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:switcher) { PageObjects::Components::DMenu.new(SWITCHER_SELECTOR) }

  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }

  fab!(:topic) { Fabricate(:topic, title: "Life strategies from The Art of War", locale: "en") }
  fab!(:post_1) do
    Fabricate(
      :post,
      topic:,
      locale: "en",
      raw: "The masterpiece isn’t just about military strategy",
    )
  end

  before do
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "es|ja"
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_cookie = true

    Fabricate(:topic_localization, topic:, locale: "ja", fancy_title: "孫子兵法からの人生戦略")
    Fabricate(
      :topic_localization,
      topic:,
      locale: "es",
      fancy_title: "Estrategias de vida de El arte de la guerra",
    )
    Fabricate(:post_localization, post: post_1, locale: "ja", cooked: "傑作は単なる軍事戦略についてではありません")
    Fabricate(
      :post_localization,
      post: post_1,
      locale: "es",
      cooked: "La obra maestra no se trata solo de estrategia militar",
    )
  end

  it "only shows the language switcher based on enabled state and what is in target languages" do
    SiteSetting.content_localization_enabled = false
    SiteSetting.content_localization_language_switcher = "anonymous"

    visit("/")
    expect(page).to have_no_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_enabled = true

    page.refresh
    switcher.expand
    expect(switcher).to have_content("English")
    expect(switcher).to have_content("Japanese (日本語)")
    expect(switcher).to have_content("Spanish (Español)")

    SiteSetting.content_localization_supported_locales = "ja"
    visit("/")

    switcher.expand
    expect(switcher).not_to have_content("Español")
  end

  it "only shows the language switcher if turned on for various types of users (anon, logged in)" do
    SiteSetting.content_localization_language_switcher = "none"
    visit("/")
    expect(page).not_to have_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_language_switcher = "anonymous"
    visit("/")
    expect(page).to have_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_language_switcher = "all"
    visit("/")
    expect(page).to have_css(SWITCHER_SELECTOR)

    sign_in(japanese_user)

    SiteSetting.content_localization_language_switcher = "none"
    visit("/")
    expect(page).not_to have_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_language_switcher = "anonymous"
    visit("/")
    expect(page).not_to have_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_language_switcher = "all"
    visit("/")
    expect(page).to have_css(SWITCHER_SELECTOR)
  end

  it "displays the current language code on the trigger button" do
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    expect(page.find(SWITCHER_SELECTOR)).to have_content("EN")

    select_language("ja")
    expect(page.find(SWITCHER_SELECTOR)).to have_content("JA")

    select_language("es")
    expect(page.find(SWITCHER_SELECTOR)).to have_content("ES")
  end

  it "shows localized content when switching languages (anon, logged in)" do
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    expect(topic_list).to have_content("Life strategies from The Art of War")

    select_language("es")

    expect(topic_list).to have_content("Estrategias de vida de El arte de la guerra")
    I18n.with_locale("es") do
      expect(page.find("#navigation-bar")).to have_content(I18n.t("js.filters.latest.title"))
    end

    sign_in(japanese_user)

    visit("/")
    expect(topic_list).to have_content("孫子兵法からの人生戦略")
    I18n.with_locale("ja") do
      expect(page.find("#navigation-bar")).to have_content(I18n.t("js.filters.latest.title"))
    end

    select_language("es")

    expect(topic_list).to have_content("Estrategias de vida de El arte de la guerra")
    I18n.with_locale("es") do
      expect(page.find("#navigation-bar")).to have_content(I18n.t("js.filters.latest.title"))
    end
  end

  it "resets localized content toggle after changing languages" do
    SiteSetting.content_localization_language_switcher = "all"

    visit("/t/#{topic.id}")

    select_language("ja")

    expect(topic_list).to have_content("孫子兵法からの人生戦略")
    expect(page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR)["title"]).to eq(
      I18n.t("js.content_localization.toggle_localized.translated"),
    )

    page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click
    expect(topic_list).to have_content("Life strategies from The Art of War")
    expect(page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR)["title"]).to eq(
      I18n.t("js.content_localization.toggle_localized.not_translated"),
    )

    select_language("es")

    expect(topic_list).to have_content("Estrategias de vida de El arte de la guerra")
    I18n.with_locale("es") do
      expect(page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR)["title"]).to eq(
        I18n.t("js.content_localization.toggle_localized.translated"),
      )
    end
  end

  it "marks the current language as selected in the dropdown" do
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    switcher.expand

    expect(page).to have_css("[data-menu-option-id='en'].--selected")
    expect(page).to have_no_css("[data-menu-option-id='ja'].--selected")
    expect(page).to have_no_css("[data-menu-option-id='es'].--selected")

    switcher.collapse
    select_language("ja")
    switcher.expand

    expect(page).to have_css("[data-menu-option-id='ja'].--selected")
    expect(page).to have_no_css("[data-menu-option-id='en'].--selected")
    expect(page).to have_no_css("[data-menu-option-id='es'].--selected")
  end

  it "strips (UK) from English (UK) when `en_GB` is the only English variant" do
    SiteSetting.default_locale = "en_GB"
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    switcher.expand
    expect(switcher).to have_content("English")
    expect(switcher).to have_no_content("English (UK)")
  end

  it "strips (BR) from Português (BR) when `pt_BR` is the only Portuguese variant" do
    SiteSetting.default_locale = "pt_BR"
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    switcher.expand
    expect(switcher).to have_content("Português")
    expect(switcher).to have_no_content("Português (UK)")
  end

  it "strips (UK) from English (UK) when `en_GB` is the only English variant in other languages too" do
    SiteSetting.default_locale = "es"
    SiteSetting.content_localization_supported_locales = "en_GB|es"
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    switcher.expand
    expect(switcher).to have_content("Inglés (English)")
    expect(switcher).to have_no_content("English (UK)")
  end

  it "does not strip (UK) from English (UK) when `en_GB` is not the only English variant" do
    SiteSetting.content_localization_supported_locales = "en|en_GB|ja"
    SiteSetting.content_localization_language_switcher = "all"

    visit("/")
    switcher.expand
    expect(switcher).to have_content("English")
    expect(switcher).to have_content("English (UK)")
  end
  def select_language(locale)
    switcher.expand
    switcher.option("[data-menu-option-id='#{locale}']").click
  end
end
