# frozen_string_literal: true

RSpec.describe "Header Search - Responsive Behavior", type: :system do
  fab!(:user)
  fab!(:topics) { Fabricate.times(20, :post).map(&:topic) }

  before do
    SiteSetting.search_experience = "search_field"
    sign_in(user)
  end

  it "appears based on scroll & screen width with search banner enabled" do
    SiteSetting.enable_welcome_banner = true
    visit "/"

    # Default desktop view should show search field
    expect(page).to have_no_css(".floating-search-input")
    expect(page).to have_no_css(".search-dropdown")

    page.scroll_to(0, 500)

    expect(page).to have_css(".floating-search-input", wait: 1)

    # Resize to narrow width
    page.current_window.resize_to(500, 1024)

    # Wait for the transition to complete and check for search icon
    expect(page).to have_css(".d-header-icons .search-dropdown", wait: 5)
    expect(page).to have_no_css(".floating-seach-input")

    # Resize back to wider width
    page.current_window.resize_to(1000, 1024)

    # Wait for the transition to complete and check for search field
    expect(page).to have_css(".floating-search-input", wait: 5)
    expect(page).to have_no_css(".search-dropdown")
  end

  it "appears when search banner is not enabled & shows / hides based on viewport width" do
    visit "/"

    # Default desktop view should show search field
    expect(page).to have_css(".floating-search-input")
    expect(page).to have_no_css(".search-dropdown")

    # Resize to narrow width
    page.current_window.resize_to(500, 1024)

    # Wait for the transition to complete and check for search icon
    expect(page).to have_css(".d-header-icons .search-dropdown", wait: 5)
    expect(page).to have_no_css(".floating-seach-input")

    # Resize back to wider width
    page.current_window.resize_to(1000, 1024)

    # Wait for the transition to complete and check for search field
    expect(page).to have_css(".floating-search-input", wait: 5)
    expect(page).to have_no_css(".search-dropdown")
  end
end
