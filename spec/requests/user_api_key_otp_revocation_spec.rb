# frozen_string_literal: true

RSpec.describe "User API key OTP revocation" do
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:otp_args) do
    {
      auth_redirect: "https://api.discourse.org/api/auth_redirect",
      application_name: "test app",
      public_key: private_key.public_key.to_pem,
    }
  end

  before { SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect] }

  def issue_otp(headers: {})
    post "/user-api-key/otp.json", params: otp_args, headers: headers
    expect(response.status).to eq(200)

    redirect_url = URI.parse(response.parsed_body.fetch("redirect_url"))
    encrypted_otp = CGI.parse(redirect_url.query).fetch("oneTimePassword").first
    private_key.private_decrypt(Base64.decode64(encrypted_otp))
  end

  it "redeems a session OTP once while its issuing session remains active" do
    user = Fabricate(:user, refresh_auto_groups: true)
    sign_in(user)
    token = issue_otp

    get "/session/otp/#{token}"
    expect(response.status).to eq(302)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "rejects an OTP after its issuing session logs out" do
    user = Fabricate(:user, refresh_auto_groups: true)
    sign_in(user)
    token = issue_otp

    delete "/session/#{user.username}.json", xhr: true
    expect(response.status).to eq(200)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
    get "/session/current.json"
    expect(response.status).to eq(404)
  end

  it "rejects an OTP after a password reset revokes its issuing session" do
    user = Fabricate(:user, refresh_auto_groups: true)
    sign_in(user)
    token = issue_otp
    reset_token = Fabricate(:email_token, user:, scope: EmailToken.scopes[:password_reset])

    put "/u/password-reset/#{reset_token.token}.json", params: { password: "new secure password" }
    expect(response.status).to eq(200)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "rejects an OTP after its issuing user API key is revoked" do
    user = Fabricate(:user, refresh_auto_groups: true)
    key =
      Fabricate(
        :user_api_key,
        user: user,
        scopes: [Fabricate.build(:user_api_key_scope, name: "write")],
      )
    token = issue_otp(headers: { "User-Api-Key" => key.key })

    get "/session/otp/#{token}"
    expect(response.status).to eq(200)

    key.update!(revoked_at: Time.zone.now)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "rejects an OTP after its issuing admin API key is revoked" do
    admin = Fabricate(:admin)
    key = Fabricate(:api_key, user: admin)
    token = issue_otp(headers: { "Api-Key" => key.key, "Api-Username" => admin.username })

    key.update!(revoked_at: Time.zone.now)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "logs in with an OTP from an active admin API key" do
    admin = Fabricate(:admin)
    key = Fabricate(:api_key, user: admin)
    token = issue_otp(headers: { "Api-Key" => key.key, "Api-Username" => admin.username })

    post "/session/otp/#{token}"
    expect(response.status).to eq(302)

    get "/session/current.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("current_user").fetch("id")).to eq(admin.id)
  end

  it "redeems an OTP after the user changes their username" do
    user = Fabricate(:user, refresh_auto_groups: true)
    key =
      Fabricate(
        :user_api_key,
        user: user,
        scopes: [Fabricate.build(:user_api_key_scope, name: "write")],
      )
    token = issue_otp(headers: { "User-Api-Key" => key.key })

    user.update!(username: "renamed_user")

    post "/session/otp/#{token}"
    expect(response.status).to eq(302)

    get "/session/current.json"
    expect(response.parsed_body.fetch("current_user").fetch("id")).to eq(user.id)
  end

  it "rejects an OTP after its issuing user API key expires" do
    user = Fabricate(:user, refresh_auto_groups: true)
    key =
      Fabricate(
        :user_api_key,
        user: user,
        scopes: [Fabricate.build(:user_api_key_scope, name: "write")],
      )
    token = issue_otp(headers: { "User-Api-Key" => key.key })

    key.update!(expires_at: 1.minute.ago)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "rejects an OTP issued during app authorization after its issuing session logs out" do
    user = Fabricate(:user, refresh_auto_groups: true)
    sign_in(user)

    post "/user-api-key.json",
         params:
           otp_args.merge(
             scopes: "read,one_time_password",
             client_id: SecureRandom.hex,
             nonce: SecureRandom.hex,
           )
    expect(response.status).to eq(200)
    redirect_url = URI.parse(response.parsed_body.fetch("redirect_url"))
    encrypted_otp = CGI.parse(redirect_url.query).fetch("oneTimePassword").first
    token = private_key.private_decrypt(Base64.decode64(encrypted_otp))

    delete "/session/#{user.username}.json", xhr: true
    expect(response.status).to eq(200)

    post "/session/otp/#{token}"
    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end

  it "rejects app authorization that would replace the OTP issuing key" do
    user = Fabricate(:user, refresh_auto_groups: true)
    key =
      Fabricate(
        :user_api_key,
        user: user,
        scopes: [Fabricate.build(:user_api_key_scope, name: "write")],
      )

    post "/user-api-key.json",
         params:
           otp_args.merge(
             scopes: "read,one_time_password",
             client_id: key.client.client_id,
             nonce: SecureRandom.hex,
           ),
         headers: {
           "User-Api-Key" => key.key,
         }

    expect(response.status).to eq(403)
    expect(key.reload.revoked_at).to be_nil
    expect(UserApiKey.where(user_id: user.id, user_api_key_client_id: key.client.id).count).to eq(1)
  end

  it "allows a clientless key to authorize a new client with an OTP" do
    user = Fabricate(:user, refresh_auto_groups: true)
    key =
      Fabricate(
        :user_api_key,
        user: user,
        scopes: [Fabricate.build(:user_api_key_scope, name: "write")],
      )
    key.update_columns(user_api_key_client_id: nil)

    post "/user-api-key.json",
         params:
           otp_args.merge(
             scopes: "read,one_time_password",
             client_id: SecureRandom.hex,
             nonce: SecureRandom.hex,
           ),
         headers: {
           "User-Api-Key" => key.key,
         }
    expect(response.status).to eq(200)
    redirect_url = URI.parse(response.parsed_body.fetch("redirect_url"))
    encrypted_otp = CGI.parse(redirect_url.query).fetch("oneTimePassword").first
    token = private_key.private_decrypt(Base64.decode64(encrypted_otp))

    post "/session/otp/#{token}"
    expect(response.status).to eq(302)
  end

  it "rejects an old unbound OTP" do
    user = Fabricate(:user)
    token = SecureRandom.hex
    Discourse.redis.setex "otp_#{token}", 10.minutes, user.username

    post "/session/otp/#{token}"

    expect(response.status).to eq(200)
    expect(response.body).to include(I18n.t("user_api_key.invalid_token"))
  end
end
