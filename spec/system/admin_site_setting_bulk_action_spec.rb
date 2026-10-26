# frozen_string_literal: true

describe "Admin Site Setting Bulk Action" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:admin)

  before { sign_in(admin) }

  it "preserves drafts across categories and saves both settings" do
    settings_page.visit

    expect(banner).to be_hidden

    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("site_description", "A cool place")

    aggregate_failures "show two unsaved settings" do
      expect(banner).to be_visible
      expect(banner.element).to have_text("You have 2 unsaved changes")
    end

    settings_page.navigate_to_category(:branding)

    aggregate_failures "keep drafts in Branding" do
      expect(banner).to be_visible
      expect(banner.element).to have_text("You have 2 unsaved changes")
    end

    settings_page.navigate_to_category(:required)

    aggregate_failures "restore both drafts in Required" do
      expect(banner).to be_visible
      expect(banner.element).to have_text("You have 2 unsaved changes")
      expect(settings_page).to have_overridden_setting("title", value: "The Shell")
      expect(settings_page).to have_overridden_setting("site_description", value: "A cool place")
    end

    banner.click_save

    aggregate_failures "commit both drafts" do
      expect(banner).to be_hidden
      expect(settings_page).to have_overridden_setting("title", value: "The Shell")
      expect(settings_page).to have_overridden_setting("site_description", value: "A cool place")
    end

    page.refresh

    aggregate_failures "reload both saved settings" do
      expect(banner).to be_hidden
      expect(settings_page).to have_overridden_setting("title", value: "The Shell")
      expect(settings_page).to have_overridden_setting("site_description", value: "A cool place")
    end
  end

  it "preserves rejected bulk drafts and confirms both settings on retry" do
    saved_password_length = SiteSetting.min_password_length
    saved_admin_password_length = SiteSetting.min_admin_password_length
    settings_page.visit("min_password")
    settings_page.fill_setting("min_password_length", 12)
    settings_page.fill_setting("min_admin_password_length", 13)

    aggregate_failures "show both password drafts" do
      expect(banner).to be_visible
      expect(banner.element).to have_text("You have 2 unsaved changes")
    end

    banner.click_save

    aggregate_failures "confirm the first password draft" do
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_password_length.prompt",
        ),
      )
    end
    dialog.click_yes

    aggregate_failures "reject the second password draft" do
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_admin_password_length.prompt",
        ),
      )
    end
    dialog.click_no

    aggregate_failures "retain both drafts after rejection" do
      expect(dialog).to be_closed
      expect(banner).to be_visible
      expect(banner.element).to have_text("You have 2 unsaved changes")
      expect(SiteSetting.min_password_length).to eq(saved_password_length)
      expect(SiteSetting.min_admin_password_length).to eq(saved_admin_password_length)
    end

    banner.click_save

    aggregate_failures "confirm the first password draft again" do
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_password_length.prompt",
        ),
      )
    end
    dialog.click_yes

    aggregate_failures "confirm the second password draft" do
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_admin_password_length.prompt",
        ),
      )
    end
    dialog.click_yes

    aggregate_failures "save the confirmed password drafts" do
      expect(settings_page).to have_overridden_setting("min_password_length", value: 12)
      expect(settings_page).to have_overridden_setting("min_admin_password_length", value: 13)
      expect(banner).to be_hidden
    end
  end

  it "pops up an error when saving invalid settings" do
    settings_page.visit
    settings_page.fill_setting("title", "The Shell")
    settings_page.fill_setting("contact_email", "Ooops")

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")

    banner.click_save

    expect(dialog).to be_open
    expect(dialog).to have_content(
      I18n.t("js.generic_error_with_reason", error: "contact_email: Invalid email address."),
    )
    dialog.click_ok

    expect(banner).to be_visible
    expect(banner.element).to have_text("You have 2 unsaved changes")
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
