# frozen_string_literal: true

describe "Content localization language switcher" do
  let(:switcher_selector) { "button[data-identifier='language-switcher']" }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:switcher) { PageObjects::Components::DMenu.new(switcher_selector) }
  let(:language_switcher) { PageObjects::Components::LanguageSwitcher.new }

  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }

  fab!(:topic) { Fabricate(:topic, title: "Life strategies from The Art of War", locale: "en") }
  fab!(:post_1) do
    Fabricate(
      :post,
      topic:,
      locale: "en",
      raw: "The masterpiece isn't just about military strategy",
    )
  end
  fab!(:post_2) do
    Fabricate(
      :post,
      topic:,
      locale: "en",
      raw: "The greatest victory is that which requires no battle",
    )
  end

  before do
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "es|ja"
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true

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

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    SiteSetting.content_localization_enabled = true

    browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    switcher.expand
    expect(switcher).to have_displayed_content("English")
    expect(switcher).to have_displayed_content("Japanese (日本語)")
    expect(switcher).to have_displayed_content("Spanish (Español)")

    SiteSetting.content_localization_supported_locales = "ja"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    switcher.expand
    expect(switcher).to have_no_displayed_content("Español")
  end

  it "only shows the language switcher if turned on for various types of users (anon, logged in)" do
    SiteSetting.content_localization_language_switcher = "none"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    SiteSetting.content_localization_language_switcher = "anonymous"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    SiteSetting.content_localization_language_switcher = "all"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    sign_in(japanese_user)

    SiteSetting.content_localization_language_switcher = "none"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    SiteSetting.content_localization_language_switcher = "anonymous"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    SiteSetting.content_localization_language_switcher = "all"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "lets anonymous visitors switch language when set_locale_from_cookie is also enabled" do
    SiteSetting.set_locale_from_cookie = true
    SiteSetting.content_localization_language_switcher = "anonymous"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    language_switcher.select_language("es")

    expect(topic_list).to have_displayed_content("Estrategias de vida de El arte de la guerra")
  end

  it "displays the current language code on the trigger button" do
    SiteSetting.content_localization_language_switcher = "all"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.contain_text(browser_text_pattern("EN"), useInnerText: true)

    language_switcher.select_language("ja")
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.contain_text(browser_text_pattern("JA"), useInnerText: true)

    language_switcher.select_language("es")
    expect(
      browser_root.locator(switcher_selector).filter(visible: true),
    ).to PlaywrightMatchers.contain_text(browser_text_pattern("ES"), useInnerText: true)
  end

  it "shows localized content when switching languages (anon, logged in)" do
    SiteSetting.content_localization_language_switcher = "all"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(topic_list).to have_displayed_content("Life strategies from The Art of War")

    language_switcher.select_language("es")

    expect(topic_list).to have_displayed_content("Estrategias de vida de El arte de la guerra")
    I18n.with_locale("es") do
      expect(
        browser_root.locator("#navigation-bar").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.filters.latest.title")),
        useInnerText: true,
      )
    end

    sign_in(japanese_user)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(topic_list).to have_displayed_content("孫子兵法からの人生戦略")
    I18n.with_locale("ja") do
      expect(
        browser_root.locator("#navigation-bar").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.filters.latest.title")),
        useInnerText: true,
      )
    end

    language_switcher.select_language("es")

    expect(topic_list).to have_displayed_content("Estrategias de vida de El arte de la guerra")
    I18n.with_locale("es") do
      expect(
        browser_root.locator("#navigation-bar").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.filters.latest.title")),
        useInnerText: true,
      )
    end
  end

  it "marks the current language as selected in the dropdown" do
    SiteSetting.content_localization_language_switcher = "all"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    switcher.expand

    expect(
      browser_root.locator("[data-menu-option-id='en'].--selected").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("[data-menu-option-id='ja'].--selected").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("[data-menu-option-id='es'].--selected").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    switcher.collapse
    language_switcher.select_language("ja")
    switcher.expand

    expect(
      browser_root.locator("[data-menu-option-id='ja'].--selected").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("[data-menu-option-id='en'].--selected").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("[data-menu-option-id='es'].--selected").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end
end
