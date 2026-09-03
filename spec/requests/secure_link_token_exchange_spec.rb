# frozen_string_literal: true

RSpec.describe "Secure link token exchange" do
  token = "a" * 64

  {
    "/u/password-reset/#{token}" => "/u/password-reset",
    "/users/password-reset/#{token}" => "/u/password-reset",
    "/u/activate-account/#{token}" => "/u/activate-account",
    "/users/activate-account/#{token}" => "/u/activate-account",
    "/u/confirm-old-email/#{token}" => "/u/confirm-old-email",
    "/users/confirm-old-email/#{token}" => "/u/confirm-old-email",
    "/u/confirm-new-email/#{token}" => "/u/confirm-new-email",
    "/users/confirm-new-email/#{token}" => "/u/confirm-new-email",
    "/u/confirm-admin/#{token}" => "/u/confirm-admin",
    "/users/confirm-admin/#{token}" => "/u/confirm-admin",
    "/session/email-login/#{token}" => "/session/email-login",
    "/session/otp/#{token}" => "/session/otp",
    "/associate/#{token}" => "/associate",
    "/invites/#{token}?t=#{token}" => "/invite",
    "/email/unsubscribe/#{token}" => "/email/unsubscribe",
  }.each do |token_path, clean_path|
    it "exchanges GET #{token_path.split("?").first} without rendering the token" do
      get token_path

      expect(response).to have_http_status(:see_other)
      expect(response.location).to eq("#{Discourse.base_url}#{clean_path}")
      expect(response.body).to be_empty
    end
  end

  {
    get: [
      "/u/password-reset/#{token}.json",
      "/users/password-reset/#{token}.json",
      "/u/activate-account/#{token}.json",
      "/users/activate-account/#{token}.json",
      "/u/confirm-old-email/#{token}.json",
      "/users/confirm-old-email/#{token}.json",
      "/u/confirm-new-email/#{token}.json",
      "/users/confirm-new-email/#{token}.json",
      "/u/confirm-admin/#{token}.json",
      "/users/confirm-admin/#{token}.json",
      "/session/email-login/#{token}.json",
      "/session/otp/#{token}.json",
      "/associate/#{token}.json",
      "/invites/#{token}.json",
      "/email/unsubscribe/#{token}.json",
    ],
    put: [
      "/u/password-reset/#{token}.json",
      "/users/password-reset/#{token}.json",
      "/u/activate-account/#{token}.json",
      "/users/activate-account/#{token}.json",
      "/u/confirm-old-email/#{token}.json",
      "/users/confirm-old-email/#{token}.json",
      "/u/confirm-new-email/#{token}.json",
      "/users/confirm-new-email/#{token}.json",
      "/invites/show/#{token}.json",
    ],
    post: [
      "/u/confirm-admin/#{token}.json",
      "/users/confirm-admin/#{token}.json",
      "/session/email-login/#{token}.json",
      "/session/otp/#{token}.json",
      "/associate/#{token}.json",
      "/email/unsubscribe/#{token}.json",
    ],
  }.each do |verb, token_paths|
    token_paths.each do |token_path|
      it "returns 404 for #{verb.upcase} #{token_path}" do
        public_send(verb, token_path)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "returns 404 for valid password-reset token APIs" do
    user = Fabricate(:user)
    email_token = Fabricate(:email_token, user:, scope: EmailToken.scopes[:password_reset]).token

    get "/u/password-reset/#{email_token}.json"
    expect(response).to have_http_status(:not_found)

    put "/u/password-reset/#{email_token}.json", params: { password: SecureRandom.hex }
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid activation token APIs" do
    user = Fabricate(:user, active: false)
    email_token = Fabricate(:email_token, user:, scope: EmailToken.scopes[:signup]).token

    get "/u/activate-account/#{email_token}.json"
    expect(response).to have_http_status(:not_found)

    put "/u/activate-account/#{email_token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid email-login token APIs" do
    user = Fabricate(:user)
    email_token = Fabricate(:email_token, user:, scope: EmailToken.scopes[:email_login]).token

    get "/session/email-login/#{email_token}.json"
    expect(response).to have_http_status(:not_found)

    post "/session/email-login/#{email_token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid new-email token APIs" do
    user = Fabricate(:user)
    updater = EmailUpdater.new(guardian: user.guardian, user:)
    token = updater.change_to("new-email@example.com").new_email_token.token

    get "/u/confirm-new-email/#{token}.json"
    expect(response).to have_http_status(:not_found)

    put "/u/confirm-new-email/#{token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid old-email token APIs" do
    user = Fabricate(:admin)
    updater = EmailUpdater.new(guardian: user.guardian, user:)
    token = updater.change_to("new-admin-email@example.com").old_email_token.token

    get "/u/confirm-old-email/#{token}.json"
    expect(response).to have_http_status(:not_found)

    put "/u/confirm-old-email/#{token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid OTP token APIs" do
    user = Fabricate(:user)
    otp_token = SecureRandom.hex
    Discourse.redis.setex("otp_#{otp_token}", 10.minutes, user.username)

    get "/session/otp/#{otp_token}.json"
    expect(response).to have_http_status(:not_found)

    post "/session/otp/#{otp_token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid admin-confirmation token APIs" do
    confirmation = AdminConfirmation.new(Fabricate(:user), Fabricate(:admin))
    confirmation.create_confirmation

    get "/u/confirm-admin/#{confirmation.token}.json"
    expect(response).to have_http_status(:not_found)

    post "/u/confirm-admin/#{confirmation.token}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for valid invite token APIs" do
    invite = Fabricate(:invite)

    get "/invites/#{invite.invite_key}.json"
    expect(response).to have_http_status(:not_found)

    put "/invites/show/#{invite.invite_key}.json"
    expect(response).to have_http_status(:not_found)
  end

  it "rejects human unsubscribe mutations that still carry a token" do
    user = Fabricate(:user)
    unsubscribe_key = UnsubscribeKey.create_key_for(user, UnsubscribeKey::DIGEST_TYPE)

    get "/email/unsubscribe/#{unsubscribe_key}.json"
    expect(response).to have_http_status(:not_found)

    post "/email/unsubscribe/#{unsubscribe_key}.json", params: { digest_after_minutes: "0" }
    expect(response).to have_http_status(:not_found)

    post "/email/unsubscribe/#{unsubscribe_key}", params: { digest_after_minutes: "0" }
    expect(response).to have_http_status(:not_found)
  end

  it "clears an older flow when a same-purpose landing is invalid" do
    user = Fabricate(:user, password: "old-password")
    email_token = Fabricate(:email_token, user:, scope: EmailToken.scopes[:password_reset]).token

    get "/u/password-reset/#{email_token}"
    expect(response).to redirect_to("/u/password-reset")

    get "/u/password-reset/#{SecureRandom.hex}"
    expect(response).to redirect_to("/u/password-reset")

    put "/u/password-reset.json", params: { password: "new-secure-password" }

    expect(response).not_to be_successful
    expect(user.reload.confirm_password?("old-password")).to eq(true)
  end

  it "binds an admin confirmation to the admin who initiated it" do
    acting_admin = Fabricate(:admin)
    target_user = Fabricate(:user)
    confirmation = AdminConfirmation.new(target_user, acting_admin)
    confirmation.create_confirmation
    sign_in(acting_admin)

    get "/u/confirm-admin/#{confirmation.token}"

    expect(response).to redirect_to("/u/confirm-admin")
    expect(target_user.reload).not_to be_admin

    post "/u/confirm-admin.json"

    expect(response).to have_http_status(:ok)
    expect(target_user.reload).to be_admin
  end

  it "rejects an admin confirmation from a different admin" do
    acting_admin = Fabricate(:admin)
    target_user = Fabricate(:user)
    confirmation = AdminConfirmation.new(target_user, acting_admin)
    confirmation.create_confirmation
    sign_in(Fabricate(:admin))

    get "/u/confirm-admin/#{confirmation.token}"

    expect(response).to redirect_to("/u/confirm-admin")

    post "/u/confirm-admin.json"

    expect(response).not_to be_successful
    expect(target_user.reload).not_to be_admin
  end

  it "returns a logged-out acting admin to the clean confirmation route" do
    acting_admin = Fabricate(:admin)
    target_user = Fabricate(:user)
    confirmation = AdminConfirmation.new(target_user, acting_admin)
    confirmation.create_confirmation

    get "/u/confirm-admin/#{confirmation.token}"
    expect(response).to redirect_to("/u/confirm-admin")

    get "/u/confirm-admin"
    expect(response).to redirect_to("/login")
    expect(response.cookies["destination_url"]).to eq("/u/confirm-admin")

    sign_in(acting_admin)
    post "/u/confirm-admin.json"

    expect(response).to have_http_status(:ok)
    expect(target_user.reload).to be_admin
  end
end
