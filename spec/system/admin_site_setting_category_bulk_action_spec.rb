# frozen_string_literal: true

describe "Admin Site Setting Category Bulk Action", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:admin)

  before { sign_in(admin) }

  it "prompts about unsaved settings when navigating away" do
    page.visit("/admin/config/notifications")

    settings_page.fill_setting("max_mentions_per_post", 2)

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 1 unsaved change")

    settings_page.find(".admin-sidebar-nav-link", text: "Login & authentication").click

    expect(settings_page).to have_current_path("/admin/config/notifications")

    expect(dialog).to be_open
    expect(dialog).to have_content("You have 1 unsaved change")

    dialog.click_no

    expect(settings_page).to have_current_path("/admin/config/login-and-authentication")
  end
end
