# frozen_string_literal: true

describe "User page search", type: :system do
  fab!(:user)
  let(:search_page) { PageObjects::Pages::Search.new }

  before do
    Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
  end

  it "filters down to the user" do
    sign_in(user)

    visit("/u/#{user.username}")
    search_page.click_search_icon
    search_page.click_in_posts_by_user

    expect(search_page).to have_found_no_results
    expect(search_page.search_term).to eq("@#{user.username}")
  end
end
