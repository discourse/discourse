# frozen_string_literal: true

RSpec.describe "User API Key Show Page" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:cdp) { PageObjects::CDP.new }
  let(:user_api_key_page) { PageObjects::Pages::UserApiKeyShow.new }

  let(:public_key) { OpenSSL::PKey::RSA.new(2048).public_key.to_pem }

  before do
    SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.enable_powered_by_discourse = true
  end

  it "lets a user authorize and copy the generated key" do
    sign_in(user)

    user_api_key_page.visit_authorization(public_key: public_key)

    expect(user_api_key_page).to have_authorization_form
    expect(user_api_key_page).to have_no_sidebar
    expect(user_api_key_page).to have_no_powered_by_discourse

    screenshot_marker(label: "user-api-key-auth")

    user_api_key_page.click_authorize

    expect(user_api_key_page).to have_payload
    expect(user_api_key_page).to have_no_sidebar
    expect(user_api_key_page).to have_no_powered_by_discourse

    cdp.allow_clipboard

    displayed_payload = user_api_key_page.payload
    expect(displayed_payload).to match(/\s/)

    user_api_key_page.click_copy_key

    expect(user_api_key_page).to have_copied_button

    clipboard_content = cdp.read_clipboard
    expect(clipboard_content).not_to match(/\s/)
    expect { Base64.decode64(clipboard_content) }.not_to raise_error
  end

  it "keeps one-time password authorization focused" do
    sign_in(user)

    user_api_key_page.visit_otp(public_key: public_key)

    expect(user_api_key_page).to have_otp_form
    expect(user_api_key_page).to have_no_sidebar
    expect(user_api_key_page).to have_no_powered_by_discourse
  end
end
