# frozen_string_literal: true

require "rotp"

RSpec.describe SessionController do
  before do
    SiteSetting.enable_local_logins_via_code = false
    SiteSetting.hide_email_address_taken = false
    Jobs.run_immediately!
  end

  describe "login required bootstrap" do
    it "keeps category metadata private in the mobile categories homepage and its data endpoint" do
      category = Fabricate(:category)
      SiteSetting.login_required = true
      SiteSetting.top_menu = "categories|latest|new|top"
      mobile_headers = {
        "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
      }

      get "/", headers: mobile_headers

      expect(response.status).to eq(200)
      expect(response.body).not_to include(category.name)
      get "/categories.json", headers: mobile_headers
      expect(response.status).to eq(403)
      expect(response.body).not_to include(category.name)
    end
  end

  describe "#email_login" do
    let(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
    let!(:totp) { Fabricate(:user_second_factor_totp, user: user) }
    let!(:backup) { Fabricate(:user_second_factor_backup, user: user) }

    before { SiteSetting.enable_local_logins_via_email = true }

    it "authenticates the emailed login token with TOTP" do
      request_email_login(user)
      token = ActionMailer::Base.deliveries.last.body.to_s[%r{/session/email-login/([a-f0-9]+)}, 1]
      expect(token).to be_present

      get "/session/email-login/#{token}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "can_login" => true,
        "second_factor_required" => true,
        "totp_enabled" => true,
        "backup_codes_enabled" => true,
      )

      post "/session/email-login/#{token}.json",
           params: {
             second_factor_method: UserSecondFactor.methods[:totp],
             second_factor_token: ROTP::TOTP.new(totp.data).now,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id, "username" => "john")
      expect(backup.reload).to be_enabled
    end

    it "authenticates the emailed login token and consumes the supplied backup code" do
      request_email_login(user)
      token = ActionMailer::Base.deliveries.last.body.to_s[%r{/session/email-login/([a-f0-9]+)}, 1]
      expect(token).to be_present

      get "/session/email-login/#{token}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "can_login" => true,
        "second_factor_required" => true,
        "totp_enabled" => true,
        "backup_codes_enabled" => true,
      )

      post "/session/email-login/#{token}.json",
           params: {
             second_factor_method: UserSecondFactor.methods[:backup_codes],
             second_factor_token: "iAmValidBackupCode",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      expect(backup.reload).not_to be_enabled
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id, "username" => "john")
    end
  end

  describe "#create" do
    it "requires TOTP after the password and authenticates the submitted user" do
      user = Fabricate(:user, username: "john", password: "supersecurepassword")
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      totp = Fabricate(:user_second_factor_totp, user: user)
      Fabricate(:user_second_factor_backup, user: user)

      post "/session.json", params: { login: user.username, password: "supersecurepassword" }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "reason" => "invalid_second_factor_method",
        "totp_enabled" => true,
        "backup_enabled" => true,
      )
      get "/session/current.json"
      expect(response.status).to eq(404)

      post "/session.json",
           params: {
             login: user.username,
             password: "supersecurepassword",
             second_factor_method: UserSecondFactor.methods[:totp],
             second_factor_token: ROTP::TOTP.new(totp.data).now,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to be_nil
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id, "username" => "john")
    end
  end

  describe "#verify_login_code" do
    it "sends no signup code and creates no account when registration is closed" do
      SiteSetting.enable_local_logins_via_email = true
      SiteSetting.enable_local_logins_via_code = true
      SiteSetting.allow_new_registrations = false
      email = "new.person@example.com"
      get "/session/csrf.json"
      expect(response.status).to eq(200)
      csrf_token = response.parsed_body["csrf"]
      get "/session/hp.json"
      expect(response.status).to eq(200)
      challenge = response.parsed_body

      expect do
        post "/session/login-code.json",
             params: {
               email: email,
               signup: true,
               password_confirmation: challenge["value"],
               challenge: challenge["challenge"].reverse,
             },
             headers: {
               "X-CSRF-Token" => csrf_token,
             }
      end.not_to change { ActionMailer::Base.deliveries.count }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      # No code is sent when registrations are closed, so any code is rejected.
      expect do
        post "/session/login-code/verify.json", params: { email: email, code: "000000" }
      end.not_to change(User, :count)
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("email_login_code.invalid_code"))
      expect(User.find_by_email(email)).to be_nil
      get "/session/current.json"
      expect(response.status).to eq(404)
    end
  end

  private

  def request_email_login(user)
    post "/u/email-login.json", params: { login: user.username }
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq("OK")
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email)
  end
end
