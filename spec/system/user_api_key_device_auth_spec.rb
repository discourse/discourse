# frozen_string_literal: true

RSpec.describe "User API key device auth" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:device_auth_page) { PageObjects::Pages::UserApiKeyDeviceAuth.new }
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:application_name) { "Test CLI" }
  let(:expires_in_seconds) { 1.day.to_i }
  let(:request_params) do
    {
      scopes: "read,write",
      client_id: "x" * 32,
      application_name: application_name,
      public_key: private_key.public_key.to_pem,
      nonce: SecureRandom.hex,
      padding: "oaep",
      expires_in_seconds: expires_in_seconds,
    }
  end

  before { SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0] }

  after { clear_user_api_key_device_auth_redis! }

  it "allows a user to authorize a device request", time: Time.zone.parse("2026-05-20 12:00:00") do
    device_request = create_user_api_key_device_auth_request!(params: request_params)
    sign_in(user)

    device_auth_page.visit_activate(request_token: device_request[:request_token])

    expect(device_auth_page).to have_authorization_details(
      application_name: application_name,
      scopes: [I18n.t("user_api_key.scopes.read"), I18n.t("user_api_key.scopes.write")],
      username: user.username,
    )
    expect(device_auth_page).to have_write_warning
    expect(device_auth_page).to have_unregistered_app_warning
    expect(device_auth_page).to have_expiry_notice(application_name: application_name)

    device_auth_page.enter_code(device_request[:user_code]).click_authorize

    expect(device_auth_page).to have_completion_message
  end

  it "allows a user to authorize a device request by manually entering the code",
     time: Time.zone.parse("2026-05-20 12:00:00") do
    device_request = create_user_api_key_device_auth_request!(params: request_params)
    sign_in(user)

    device_auth_page.visit_activate.enter_code(device_request[:user_code]).click_continue

    expect(device_auth_page).to have_authorization_details(
      application_name: application_name,
      scopes: [I18n.t("user_api_key.scopes.read"), I18n.t("user_api_key.scopes.write")],
      username: user.username,
    )

    device_auth_page.click_authorize

    expect(device_auth_page).to have_completion_message
  end

  it "rejects an incorrect code for a request token" do
    device_request = create_user_api_key_device_auth_request!(params: request_params)
    sign_in(user)

    device_auth_page.visit_activate(request_token: device_request[:request_token])
    device_auth_page.enter_code("BADCODE1").click_authorize

    expect(device_auth_page).to have_invalid_code_message
    expect(UserApiKey.exists?(user_id: user.id)).to eq(false)
  end
end
