# frozen_string_literal: true

describe "Admin Site Setting Bulk Action", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  fab!(:admin)

  before { sign_in(admin) }

  it "saves multiple site settings" do
    settings_page.visit

    expect(banner).to be_hidden

    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("site_description", "A cool place")

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    banner.click_save

    expect(banner).to be_hidden
    expect(settings_page).to have_overridden_setting("title", value: "The Shell")
    expect(settings_page).to have_overridden_setting("site_description", value: "A cool place")
  end

  it "shows a confirmation message for settings that require it" do
    settings_page.visit("min_password")
    settings_page.fill_setting("min_password_length", 12)
    settings_page.fill_setting("min_admin_password_length", 13)

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    banner.click_save

    2.times do
      expect(dialog).to be_open
      expect(dialog).to have_content("You’re about to change your password policy.")
      dialog.click_yes
    end

    expect(settings_page).to have_overridden_setting("min_password_length", value: 12)
    expect(settings_page).to have_overridden_setting("min_admin_password_length", value: 13)
  end

  it "cancels saving if rejecting a confirmation" do
    settings_page.visit("min_password")
    settings_page.fill_setting("min_password_length", 12)
    settings_page.fill_setting("min_admin_password_length", 13)

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    banner.click_save

    expect(dialog).to be_open
    expect(dialog).to have_content("You’re about to change your password policy.")
    dialog.click_yes

    expect(dialog).to be_open
    expect(dialog).to have_content("You’re about to change your password policy.")
    dialog.click_no

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")
  end

  it "pops up an error when saving invalid settings" do
    settings_page.visit
    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("contact_email", "Ooops")

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    banner.click_save

    expect(dialog).to be_open
    expect(dialog).to have_content("An error occurred: contact_email: Invalid email address.")
    dialog.click_ok

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")
  end

  it "persists unsaved settings when browsing categories" do
    settings_page.visit

    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("site_description", "A cool place")

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    settings_page.navigate_to_category(:branding)

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    settings_page.navigate_to_category(:required)

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    expect(settings_page).to have_overridden_setting("title", value: "The Shell")
    expect(settings_page).to have_overridden_setting("site_description", value: "A cool place")
  end

  it "prompts about unsaved settings when navigating away" do
    settings_page.visit

    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("site_description", "A cool place")

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    settings_page.find(".admin-sidebar-nav-link", text: "Dashboard").click

    expect(settings_page).to have_current_path("/admin/site_settings/category/required")

    expect(dialog).to be_open
    expect(dialog).to have_content("You have 2 unsaved changes")

    dialog.click_no

    expect(settings_page).to have_current_path("/admin")
  end
end
