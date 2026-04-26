# frozen_string_literal: true

describe "Admin Site Setting Requires Confirmation" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  fab!(:admin)

  before do
    SiteSetting.min_password_length = 10
    sign_in(admin)
  end

  it "requires confirmation and shows the correct message" do
    settings_page.visit("min_password_length")
    settings_page.change_number_setting("min_password_length", 12)
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
    dialog.click_yes
    expect(dialog).to be_closed
    expect(settings_page).to have_overridden_setting("min_password_length", value: 12)
  end

  it "does not save the new setting value if the admin cancels confirmation" do
    settings_page.visit("min_password_length")
    settings_page.change_number_setting("min_password_length", 12)
    expect(dialog).to be_open
    dialog.click_no
    expect(dialog).to be_closed
    expect(settings_page).to have_no_overridden_setting("min_password_length")
  end

  context "with simple_on_enable confirmation type" do
    it "shows confirmation when enabling the setting" do
      settings_page.visit("can_permanently_delete")
      settings_page.toggle_bool_setting("can_permanently_delete")
      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t(
          "admin_js.admin.site_settings.requires_confirmation_messages.can_permanently_delete.prompt",
        ),
      )
    end

    it "does not show confirmation when disabling the setting" do
      SiteSetting.can_permanently_delete = true
      settings_page.visit("can_permanently_delete")
      settings_page.toggle_bool_setting("can_permanently_delete")
      expect(dialog).to be_closed
    end
  end
end
