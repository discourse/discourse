# frozen_string_literal: true

describe "Admin Site Texts Page", type: :system do
  fab!(:admin)

  let(:site_texts_page) { PageObjects::Pages::AdminSiteTexts.new }

  before { sign_in(admin) }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  it "can search for client text using the default locale" do
    site_texts_page.visit
    site_texts_page.search("skip to main content")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(I18n.t("js.skip_to_main_content"))

    site_texts_page.visit
    site_texts_page.search("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(I18n.t("js.skip_to_main_content"))
  end

  it "can search for server text using the default locale" do
    site_texts_page.visit
    site_texts_page.search("Something went wrong updating theme")
    expect(site_texts_page).to have_translation_key("themes.other_error")
    expect(site_texts_page).to have_translation_value(I18n.t("themes.other_error"))

    site_texts_page.visit
    site_texts_page.search("themes.other_error")
    expect(site_texts_page).to have_translation_key("themes.other_error")
    expect(site_texts_page).to have_translation_value(I18n.t("themes.other_error"))
  end

  it "can search for text using the selected locale" do
    site_texts_page.visit
    site_texts_page.select_locale("it")
    site_texts_page.search("Passa al contenuto principale")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(
      I18n.t("js.skip_to_main_content", locale: "it"),
    )

    site_texts_page.visit
    site_texts_page.select_locale("it")
    site_texts_page.search("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(
      I18n.t("js.skip_to_main_content", locale: "it"),
    )
  end

  it "can show only overridden translations" do
    site_texts_page.visit
    site_texts_page.search("skip")
    site_texts_page.toggle_only_show_overridden
    expect(page).to have_css(".site-text", count: 0)

    TranslationOverride.create!(
      locale: "en",
      translation_key: "js.skip_to_main_content",
      value: "Overridden skip text",
      original_translation: I18n.t("js.skip_to_main_content"),
    )
    I18n.reload!

    site_texts_page.visit
    site_texts_page.search("skip")
    site_texts_page.toggle_only_show_overridden
    expect(page).to have_css(".site-text", count: 1)
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
  end

  it "can show only outddated translations" do
    site_texts_page.visit
    site_texts_page.search("skip")
    site_texts_page.toggle_only_show_outdated
    expect(page).to have_css(".site-text", count: 0)

    TranslationOverride.create!(
      locale: "en",
      translation_key: "js.skip_to_main_content",
      value: "Overridden skip text",
      original_translation: I18n.t("js.skip_to_main_content"),
      status: "outdated",
    )
    I18n.reload!

    site_texts_page.visit
    site_texts_page.search("skip")
    site_texts_page.toggle_only_show_outdated
    expect(page).to have_css(".site-text", count: 1)
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
  end

  it "can show results in the selected locale" do
    site_texts_page.visit
    site_texts_page.search("skip to main content")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(I18n.t("js.skip_to_main_content"))

    site_texts_page.toggle_only_show_results_in_selected_locale
    site_texts_page.select_locale("it")
    expect(site_texts_page).to have_translation_key("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value(
      I18n.t("js.skip_to_main_content", locale: "it"),
    )
  end

  it "can edit a translation string" do
    site_texts_page.visit
    site_texts_page.search("skip to main content")
    site_texts_page.edit_translation("js.skip_to_main_content")
    site_texts_page.override_translation("Some overridden value")
    site_texts_page.visit
    site_texts_page.search("js.skip_to_main_content")
    expect(site_texts_page).to have_translation_value("Some overridden value")
    expect(TranslationOverride.exists?(translation_key: "js.skip_to_main_content")).to eq(true)
  end

  it "properly display category names in replace text modal" do
    site_texts_page.visit
    site_texts_page.click_replace_text_button

    expect(page.all(".modal label span").map(&:text)).to eq(["Uncategorized"])
  end
end
