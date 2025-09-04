# frozen_string_literal: true

describe "Content localization language switcher", type: :system do
  SWITCHER_SELECTOR = "button[data-identifier='language-switcher']"

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

  it "only shows the language switcher based on what is in target languages" do
    SiteSetting.content_localization_language_switcher = "anonymous"
    visit("/")

    switcher.expand
    expect(switcher).to have_content("English (US)")
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

  def select_language(locale)
    switcher.expand
    switcher.option("[data-menu-option-id='#{locale}']").click
  end
end
