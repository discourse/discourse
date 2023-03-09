# frozen_string_literal: true

describe "Viewing sidebar mobile", type: :system, js: true, mobile: true do
  fab!(:user) { Fabricate(:user) }
  let(:sidebar_dropdown) { PageObjects::Components::SidebarHeaderDropdown.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    sign_in(user)
  end

  it "does not display the sidebar by default" do
    visit("/latest")

    expect(sidebar_dropdown).to be_hidden
  end

  it "does not display the keyboard shortcuts button" do
    visit("/latest")

    sidebar_dropdown.click

    expect(sidebar_dropdown).to be_visible
    expect(sidebar_dropdown).to have_no_keyboard_shortcuts_button
  end

  it "collapses the sidebar when clicking outside of it" do
    visit("/latest")

    sidebar_dropdown.click

    expect(sidebar_dropdown).to be_visible

    sidebar_dropdown.click_outside

    expect(sidebar_dropdown).to be_hidden
  end

  it "collpases the sidebar when clicking on a link in the sidebar" do
    visit("/latest")

    sidebar_dropdown.click

    expect(sidebar_dropdown).to be_visible

    sidebar_dropdown.click_everything_link

    expect(sidebar_dropdown).to be_hidden
  end

  it "collapses the sidebar when clicking on a button in the sidebar" do
    visit("/latest")

    sidebar_dropdown.click

    expect(sidebar_dropdown).to be_visible

    sidebar_dropdown.click_community_header_button

    expect(composer).to be_opened
    expect(sidebar_dropdown).to be_hidden
  end

  it "toggles to desktop view after clicking on the toggle to desktop view button" do
    visit ("/latest")

    expect(page).to have_css(".mobile-view")

    sidebar_dropdown.click
    sidebar_dropdown.click_toggle_to_desktop_view_button

    visit ("/latest")

    expect(page).to have_css(".desktop-view")
  end
end
