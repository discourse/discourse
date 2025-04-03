# frozen_string_literal: true

describe "Search | Welcome banner", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:welcome_banner) { PageObjects::Components::WelcomeBanner.new }
  let(:search_page) { PageObjects::Pages::Search.new }

  before { sign_in(current_user) }

  context "when search_experience is search_icon" do
    before do
      SiteSetting.enable_welcome_banner = true
      SiteSetting.search_experience = "search_icon"
    end

    it "focuses input after selecting a result" do
      visit("/")
      expect(welcome_banner).to be_visible
      search_page.type_in_banner_search("text")
      page.send_keys(:arrow_down)
      page.send_keys(:enter)
      expect(page).to have_field("welcome-banner-search-term", focused: true)
      expect(current_active_element[:id]).to eq("welcome-banner-search-term")
    end

    it "focuses input after clearing" do
      visit("/")
      expect(welcome_banner).to be_visible
      search_page.type_in_banner_search("text")
      find(".clear-search").click
      expect(current_active_element[:id]).to eq("welcome-banner-search-term")
    end
  end
end
