# frozen_string_literal: true

RSpec.describe "Header Search - Responsive Behavior", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  let(:search_page) { PageObjects::Pages::Search.new }

  before do
    Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_field")
  end

  context "when welcome banner is enabled" do
    it "appears based on scroll & screen width with search banner enabled" do
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
      sign_in(current_user)
      visit "/"

      expect(search_page).to have_no_search_field
      expect(search_page).to have_no_search_icon

      fake_scroll_down_long

      expect(search_page).to have_search_field

      page.current_window.resize_to(500, 1024)

      expect(search_page).to have_search_icon
      expect(search_page).to have_no_search_field

      page.current_window.resize_to(1000, 1024)

      expect(search_page).to have_search_field
      expect(search_page).to have_no_search_icon
    end

    it "appears when search banner is not enabled & shows / hides based on viewport width" do
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      sign_in(current_user)
      visit "/"

      expect(search_page).to have_search_field
      expect(search_page).to have_no_search_icon

      page.current_window.resize_to(500, 1024)

      expect(search_page).to have_search_icon
      expect(search_page).to have_no_search_field

      page.current_window.resize_to(1000, 1024)

      expect(search_page).to have_search_field
      expect(search_page).to have_no_search_icon
    end

    it "does not appear when search setting is set to icon" do
      Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_icon")

      sign_in(current_user)
      visit "/"

      expect(search_page).to have_no_search_field
    end
  end
end
