# frozen_string_literal: true

require "rotp"

RSpec.describe UsersController do
  let(:invite) { Fabricate(:invite) }

  before do
    SiteSetting.enable_local_logins_via_code = false
    SiteSetting.hide_email_address_taken = false
    Jobs.run_immediately!
  end

  describe "#create" do
    before { invite }

    it "rejects a common password without creating an account" do
      expect { register_user(password: "0123456789") }.not_to change(User, :count)

      expect(response.parsed_body["success"]).to eq(false)
      expect(response.parsed_body["message"]).to include(
        I18n.t("activerecord.errors.models.user_password.attributes.password.common"),
      )

      get "/session/current.json"
      expect(response.status).to eq(404)
    end

    it "accepts the configured signup invite code" do
      SiteSetting.invite_code = "cupcake"

      expect { register_user(invite_code: "cupcake") }.to change(User, :count).by(1)

      user = User.find_by!(username: "john")
      expect(response.parsed_body).to include(
        "success" => true,
        "active" => false,
        "user_id" => user.id,
        "message" => I18n.t("login.activate_email", email: user.email),
      )
      expect(user.email).to eq(invite.email)
      expect(user).not_to be_active
      expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email)
    end

    it "persists a required custom field supplied during signup" do
      field =
        Fabricate(
          :user_field,
          name: "Occupation",
          requirement: "on_signup",
          description: "What you do for work",
        )

      expect { register_user(user_fields: { field.id.to_s => "Jedi" }) }.to change(User, :count).by(
        1,
      )

      user = User.find_by!(username: "john")
      expect(response.parsed_body).to include(
        "success" => true,
        "active" => false,
        "user_id" => user.id,
        "message" => I18n.t("login.activate_email", email: user.email),
      )
      expect(user.user_fields[field.id.to_s]).to eq("Jedi")
      expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email)
    end

    it "requires approval before password login and allows login after approval and activation" do
      SiteSetting.must_approve_users = true
      SiteSetting.auto_approve_email_domains = "awesomeemail.com"
      admin = Fabricate(:admin)

      expect { register_user }.to change(User, :count).by(1)
      expect(response.parsed_body["success"]).to eq(true)
      user = User.find_by!(username: "john")
      expect(user).not_to be_approved
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      activation_token = mail.body.to_s[%r{/u/activate-account/([a-f0-9]+)}, 1]
      expect(activation_token).to be_present

      post "/session.json", params: { login: user.username, password: "supersecurepassword" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("login.not_approved"))
      get "/session/current.json"
      expect(response.status).to eq(404)

      activate_account(activation_token)
      expect(response.parsed_body).to include("success" => "OK", "needs_approval" => true)
      expect(user.reload).to be_active
      expect(user).not_to be_approved
      get "/session/current.json"
      expect(response.status).to eq(404)

      sign_in(admin)
      put "/admin/users/#{user.id}/approve.json"
      expect(response.status).to eq(200)
      expect(user.reload).to be_approved
      sign_out

      post "/session.json", params: { login: user.username, password: "supersecurepassword" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to be_nil
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id, "username" => "john")
    end

    it "automatically approves the configured email domain and permits activated password login" do
      SiteSetting.must_approve_users = true
      SiteSetting.auto_approve_email_domains = "awesomeemail.com"

      expect { register_user(email: "johndoe@awesomeemail.com") }.to change(User, :count).by(1)

      expect(response.parsed_body["success"]).to eq(true)
      user = User.find_by!(username: "john")
      expect(user).to be_approved
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      activation_token = mail.body.to_s[%r{/u/activate-account/([a-f0-9]+)}, 1]
      expect(activation_token).to be_present

      activate_account(activation_token)
      expect(response.parsed_body).to include("success" => "OK", "needs_approval" => false)
      expect(user.reload).to be_active
      expect(user).to be_email_confirmed
      sign_out

      post "/session.json", params: { login: user.username, password: "supersecurepassword" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to be_nil
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id, "username" => "john")
    end

    it "rejects a blocked domain during both email validation and signup" do
      SiteSetting.blocked_email_domains = "example.com"
      email = "blocked@example.com"

      get "/u/check_email.json", params: { email: email }
      expect(response.status).to eq(200)
      expect(response.parsed_body["errors"]).to include(
        User.new.errors.full_message(:email, I18n.t("user.email.not_allowed")),
      )

      expect { register_user(email: email) }.not_to change(User, :count)
      expect(response.parsed_body["success"]).to eq(false)
      expect(response.parsed_body["message"]).to include(I18n.t("user.email.not_allowed"))

      get "/session/current.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#perform_account_activation" do
    it "activates an admin from the delivered email and directs them to the wizard" do
      SiteSetting.wizard_enabled = true
      SiteSetting.bypass_wizard_check = false
      admin = Fabricate(:admin, username: "admin", password: "supersecurepassword")

      post "/session.json", params: { login: admin.username, password: "supersecurepassword" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["reason"]).to eq("not_activated")

      post "/u/action/send_activation_email.json", params: { username: admin.username }
      expect(response.status).to eq(200)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(admin.email)
      activation_token = mail.body.to_s[%r{/u/activate-account/([a-f0-9]+)}, 1]
      expect(activation_token).to be_present

      activate_account(activation_token)
      expect(response.parsed_body).to include(
        "success" => "OK",
        "needs_approval" => false,
        "redirect_to" => "/wizard",
      )
      expect(admin.reload).to be_active
      expect(admin).to be_email_confirmed
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => admin.id)
    end

    it "rejects an invalid activation token and leaves the session anonymous" do
      get "/session/hp.json"
      expect(response.status).to eq(200)
      challenge = response.parsed_body

      put "/u/activate-account/123abc.json",
          params: {
            password_confirmation: challenge["value"],
            challenge: challenge["challenge"].reverse,
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(I18n.t("activation.already_done"))
      get "/session/current.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#password_reset_update" do
    it "resets a password using the delivered email and consumes a backup code" do
      user = Fabricate(:user, username: "john", password: "supersecurepassword")
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      totp = Fabricate(:user_second_factor_totp, user: user)
      backup = Fabricate(:user_second_factor_backup, user: user)

      post "/session/forgot_password.json", params: { login: user.username }
      expect(response.status).to eq(200)
      expect(response.parsed_body["user_found"]).to eq(true)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      reset_token = mail.body.to_s[%r{/u/password-reset/([a-f0-9]+)}, 1]
      expect(reset_token).to be_present

      get "/u/password-reset/#{reset_token}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "second_factor_required" => true,
        "backup_enabled" => true,
      )

      put "/u/password-reset/#{reset_token}.json",
          params: {
            password: "newsuperpassword",
            second_factor_method: UserSecondFactor.methods[:backup_codes],
            second_factor_token: "iAmValidBackupCode",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include("success" => true, "requires_approval" => false)
      expect(backup.reload).not_to be_enabled
      get "/session/current.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]).to include("id" => user.id)
      sign_out

      post "/session.json",
           params: {
             login: user.username,
             password: "newsuperpassword",
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

  private

  def register_user(**attributes)
    get "/session/csrf.json"
    expect(response.status).to eq(200)
    csrf_token = response.parsed_body["csrf"]
    get "/session/hp.json"
    expect(response.status).to eq(200)
    challenge = response.parsed_body

    post "/u.json",
         params: {
           email: invite.email,
           username: "john",
           password: "supersecurepassword",
           password_confirmation: challenge["value"],
           challenge: challenge["challenge"].reverse,
         }.merge(attributes),
         headers: {
           "X-CSRF-Token" => csrf_token,
         }
    expect(response.status).to eq(200)
  end

  def activate_account(token)
    get "/session/csrf.json"
    expect(response.status).to eq(200)
    csrf_token = response.parsed_body["csrf"]
    get "/session/hp.json"
    expect(response.status).to eq(200)
    challenge = response.parsed_body

    put "/u/activate-account/#{token}.json",
        params: {
          password_confirmation: challenge["value"],
          challenge: challenge["challenge"].reverse,
        },
        headers: {
          "X-CSRF-Token" => csrf_token,
        }
    expect(response.status).to eq(200)
  end
end
