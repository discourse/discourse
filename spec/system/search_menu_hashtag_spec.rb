# frozen_string_literal: true

describe "Search menu hashtag autocomplete" do
  let(:search_page) { PageObjects::Pages::Search.new }
  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "UX", slug: "ux") }
  fab!(:tag) { Fabricate(:tag, name: "design") }

  before do
    SiteSetting.tagging_enabled = true
    Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
    sign_in(user)
  end

  it "preserves prior hashtag when selecting a suggestion for a second hashtag" do
    visit("/")
    search_page.click_search_icon
    search_page.type_in_search_menu("#ux #des")

    expect(page).to have_css(".search-menu-assistant-item.tag")
    find(".search-menu-assistant-item.tag", match: :first).click

    expect(page).to have_field("icon-search-input", with: "#ux #design")
  end
end
