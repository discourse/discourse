# frozen_string_literal: true

describe "Admin Site Setting Requires Confirmation" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:admin)

  before do
    SiteSetting.min_password_length = 10
    sign_in(admin)
  end

  it "cancels and confirms numeric changes through pointer and Enter submission" do
    settings_page.visit("min_password_length")
    settings_page.change_number_setting("min_password_length", 12)

    aggregate_failures "cancel pointer submission" do
      expect(dialog).to be_open
    end

    dialog.click_no

    aggregate_failures "preserve the saved value after cancellation" do
      expect(dialog).to be_closed
      expect(settings_page).to have_no_overridden_setting("min_password_length")
      expect(SiteSetting.min_password_length).to eq(10)
    end

    settings_page.cancel_setting("min_password_length")
    expect(settings_page).to have_setting_value("min_password_length", value: 10)
    expect(settings_page).to have_no_pending_setting("min_password_length")
    settings_page.submit_setting_with_keyboard("min_password_length", 12)
    expect(dialog).to be_open

    dialog.click_no
    expect(dialog).to be_closed
    expect(SiteSetting.min_password_length).to eq(10)
    settings_page.cancel_setting("min_password_length")
    expect(settings_page).to have_setting_value("min_password_length", value: 10)
    expect(settings_page).to have_no_pending_setting("min_password_length")

    settings_page.change_number_setting("min_password_length", 12)

    aggregate_failures "show the numeric confirmation message" do
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_password_length.prompt",
        ),
      )
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.min_password_length.confirm",
        ),
      )
    end

    dialog.click_yes

    aggregate_failures "save the confirmed numeric value" do
      expect(dialog).to be_closed
      expect(settings_page).to have_overridden_setting("min_password_length", value: 12)
      expect(settings_page).to have_no_pending_setting("min_password_length")
      expect(SiteSetting.min_password_length).to eq(12)
    end

    page.refresh
    expect(settings_page).to have_overridden_setting("min_password_length", value: 12)
  end

  context "with simple_on_enable confirmation type" do
    it "confirms enabling permanent deletion and disables it after reloading the saved value" do
      settings_page.visit("can_permanently_delete")
      settings_page.toggle_bool_setting("can_permanently_delete")

      aggregate_failures "confirm enabling permanent deletion" do
        expect(dialog).to be_open
        expect(dialog).to have_content(
          I18n.t(
            "admin_js.admin.site_settings.requires_confirmation_messages.can_permanently_delete.prompt",
          ),
        )
      end

      dialog.click_yes
      expect(dialog).to be_closed
      expect(settings_page).to have_no_pending_setting("can_permanently_delete")
      expect(SiteSetting.can_permanently_delete).to eq(true)

      page.refresh

      aggregate_failures "hydrate the enabled value before disabling" do
        expect(settings_page.bool_setting_checkbox("can_permanently_delete")).to be_checked
        expect(dialog).to be_closed
      end

      settings_page.toggle_bool_setting("can_permanently_delete")
      expect(dialog).to be_closed
      expect(settings_page).to have_no_pending_setting("can_permanently_delete")
      expect(SiteSetting.can_permanently_delete).to eq(false)
    end

    it "explains the effect of enabling the MCP server" do
      settings_page.visit("mcp_server_enabled")
      settings_page.toggle_bool_setting("mcp_server_enabled")

      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.mcp_server_enabled.prompt",
        ),
      )
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.mcp_server_enabled.confirm",
        ),
      )
    end
  end

  context "with simple_on_disable confirmation type" do
    it "shows confirmation when disabling the setting but not when enabling it" do
      settings_page.visit("content_security_policy")
      settings_page.toggle_bool_setting("content_security_policy")
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.content_security_policy.prompt",
        ),
      )
      dialog.click_yes
      expect(dialog).to be_closed
      expect(settings_page).to have_overridden_setting("content_security_policy")

      settings_page.toggle_bool_setting("content_security_policy")
      expect(dialog).to be_closed
      expect(settings_page).to have_no_overridden_setting("content_security_policy")
    end
  end
end
