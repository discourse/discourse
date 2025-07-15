# frozen_string_literal: true

require "rails_helper"

describe "OAuth2 Overrides Email", type: :request do
  fab!(:initial_email) { "initial@example.com" }
  fab!(:new_email) { "new@example.com" }
  fab!(:user) { Fabricate(:user, email: initial_email) }
  fab!(:uac) do
    UserAssociatedAccount.create!(user: user, provider_name: "oauth2_basic", provider_uid: "12345")
  end

  before do
    SiteSetting.oauth2_enabled = true
    SiteSetting.oauth2_callback_user_id_path = "uid"
    SiteSetting.oauth2_fetch_user_details = false
    SiteSetting.oauth2_email_verified = true

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:oauth2_basic] = OmniAuth::AuthHash.new(
      provider: "oauth2_basic",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: new_email),
      extra: {
        raw_info: OmniAuth::AuthHash.new(email_verified: true),
      },
      credentials: OmniAuth::AuthHash.new,
    )
  end

  it "doesn't update email by default" do
    expect(user.reload.email).to eq(initial_email)

    get "/auth/oauth2_basic/callback"
    expect(response.status).to eq(302)
    expect(session[:current_user_id]).to eq(user.id)

    expect(user.reload.email).to eq(initial_email)
  end

  it "updates user email if enabled" do
    SiteSetting.oauth2_overrides_email = true

    get "/auth/oauth2_basic/callback"
    expect(response.status).to eq(302)
    expect(session[:current_user_id]).to eq(user.id)

    expect(user.reload.email).to eq(new_email)
  end
end
