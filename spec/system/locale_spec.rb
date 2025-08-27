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
end
