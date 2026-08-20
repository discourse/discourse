# frozen_string_literal: true

describe "Admin site setting string" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)

  before { sign_in(admin) }

  it "saves a string setting with the ok button and with the Enter key" do
    settings_page.visit("site_description")
    settings_page.fill_setting("site_description", "A place to talk")
    settings_page.save_setting("site_description")

    expect(settings_page).to have_overridden_setting("site_description", value: "A place to talk")

    settings_page.visit("company_name")
    settings_page.submit_setting_with_keyboard("company_name", "Acme")

    expect(settings_page).to have_overridden_setting("company_name", value: "Acme")

    page.refresh

    expect(settings_page).to have_overridden_setting("company_name", value: "Acme")
  end

  it "masks a secret setting until the admin reveals it" do
    settings_page.visit("github_client_secret")
    settings_page.fill_setting("github_client_secret", "s3cr3t")

    expect(settings_page.secret_setting_input("github_client_secret")[:type]).to eq("password")

    settings_page.reveal_secret_setting("github_client_secret")

    expect(settings_page.secret_setting_input("github_client_secret")[:type]).to eq("text")
  end
end
