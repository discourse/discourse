# frozen_string_literal: true

RSpec.describe "Anonymous user language switcher", type: :system do
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

  fab!(:topic_localization) do
    Fabricate(:topic_localization, topic:, locale: "ja", fancy_title: "孫子兵法からの人生戦略")
  end

  fab!(:post_localization) do
    Fabricate(:post_localization, post: post_1, locale: "ja", cooked: "傑作は単なる軍事戦略についてではありません")
  end

  before do
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "es|ja"
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_cookie = true
  end

  it "only shows the language switcher based on what is in target languages" do
    SiteSetting.content_localization_anon_language_switcher = false
    visit("/")

    expect(page).not_to have_css(SWITCHER_SELECTOR)

    SiteSetting.content_localization_anon_language_switcher = true
    visit("/")

    switcher.expand
    expect(switcher).to have_content("English (US)")
    expect(switcher).to have_content("日本語")
    expect(switcher).to have_content("Español")

    SiteSetting.content_localization_supported_locales = "ja"
    visit("/")

    switcher.expand
    expect(switcher).not_to have_content("Español")
    switcher.option("[data-menu-option-id='ja']").click
    expect(topic_list).to have_content("孫子兵法からの人生戦略")
    I18n.with_locale("ja") do
      expect(page.find("#navigation-bar")).to have_content(I18n.t("js.filters.latest.title"))
    end

    sign_in(japanese_user)
    expect(page).not_to have_css(SWITCHER_SELECTOR)
  end
end
