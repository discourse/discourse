# frozen_string_literal: true

RSpec.describe "User API Key Show Page", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:cdp) { PageObjects::CDP.new }

  let(:public_key) { OpenSSL::PKey::RSA.new(2048).public_key.to_pem }

  before { SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0] }

  it "displays the copy button and copies the payload without whitespace" do
    sign_in(user)

    # Visit the authorization page (no auth_redirect means show page after submit)
    visit "/user-api-key/new?#{URI.encode_www_form(scopes: "read", client_id: "x" * 32, application_name: "Test Application", public_key: public_key, nonce: SecureRandom.hex)}"

    # Submit the authorization form
    click_button I18n.t("user_api_key.authorize")

    # Now we should be on the show page
    expect(page).to have_css("#user-api-key-payload")
    expect(page).to have_css("#copy-api-key-btn")

    cdp.allow_clipboard

    displayed_payload = find("#user-api-key-payload").text

    # The displayed payload should have whitespace (rendered from newlines in Base64.encode64)
    expect(displayed_payload).to match(/\s/)

    find("#copy-api-key-btn").click

    # Verify button text changes to "Copied"
    expect(page).to have_button(I18n.t("user_api_key.copied"))

    # Verify clipboard contains payload without whitespace
    clipboard_content = cdp.read_clipboard
    expect(clipboard_content).not_to match(/\s/)

    # Verify the copied content can be base64 decoded
    expect { Base64.decode64(clipboard_content) }.not_to raise_error
  end
end
