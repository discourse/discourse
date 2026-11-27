# frozen_string_literal: true

RSpec.describe SessionController do
  describe "#create_login_code" do
    fab!(:existing_user, :user)

    let(:email) { "new.person@example.com" }

    before do
      Jobs.run_immediately!
      SiteSetting.enable_local_logins_via_email = true
      SiteSetting.enable_local_logins_via_code = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "site-key"
      SiteSetting.hcaptcha_secret_key = "secret-key"
    end

    def honeypot_magic(params)
      get "/session/hp.json"
      json = response.parsed_body
      params.merge(password_confirmation: json["value"], challenge: json["challenge"].reverse)
    end

    def solve_captcha
      post "/captcha/hcaptcha/create.json", params: { token: "captcha-token" }
    end

    def emailed_code
      ActionMailer::Base.deliveries.last.subject[/(\d{6})/, 1]
    end

    def stub_captcha_verification
      stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
        body: {
          secret: SiteSetting.hcaptcha_secret_key,
          response: "captcha-token",
        },
      ).to_return(status: 200, body: '{"success":true}')
    end

    it "does not email a code without completing CAPTCHA" do
      post "/session/login-code.json", params: honeypot_magic(email:)

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(EmailLoginCode.for_email(email).count).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "challenges existing accounts too, so the response does not reveal them" do
      post "/session/login-code.json", params: honeypot_magic(email: existing_user.email)

      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(EmailLoginCode.for_email(existing_user.email).count).to eq(0)
    end

    it "emails a code after the CAPTCHA provider verifies the challenge" do
      stub_captcha_verification
      solve_captcha

      post "/session/login-code.json", params: honeypot_magic(email:)

      expect(response.parsed_body["success"]).to eq("OK")
      expect(EmailLoginCode.for_email(email).count).to eq(1)
    end

    it "does not email a code when the CAPTCHA provider rejects the challenge" do
      stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).to_return(
        status: 200,
        body: '{"success":false}',
      )
      solve_captcha

      post "/session/login-code.json", params: honeypot_magic(email:)

      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(EmailLoginCode.for_email(email).count).to eq(0)
    end

    it "lets the same session resend a code to the same address without another challenge" do
      verification_request = stub_captcha_verification
      solve_captcha
      post "/session/login-code.json", params: honeypot_magic(email:)

      post "/session/login-code.json", params: honeypot_magic(email:)

      expect(response.parsed_body["success"]).to eq("OK")
      expect(verification_request).to have_been_requested.once
    end

    it "challenges again before emailing a different address" do
      stub_captcha_verification
      solve_captcha
      post "/session/login-code.json", params: honeypot_magic(email:)

      post "/session/login-code.json", params: honeypot_magic(email: "someone.else@example.com")

      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(EmailLoginCode.for_email("someone.else@example.com").count).to eq(0)
    end

    it "does not challenge invitations" do
      invite = Fabricate(:invite, email: "invited@example.com")

      post "/session/login-code.json",
           params: honeypot_magic(email: invite.email, invite_key: invite.invite_key)

      expect(response.parsed_body["error"]).to be_nil
      expect(EmailLoginCode.for_email(invite.email).count).to eq(1)
    end

    it "does not challenge when CAPTCHA is disabled" do
      SiteSetting.discourse_captcha_enabled = false

      post "/session/login-code.json", params: honeypot_magic(email:)

      expect(response.parsed_body["success"]).to eq("OK")
      expect(EmailLoginCode.for_email(email).count).to eq(1)
    end

    it "creates the account without a second challenge" do
      verification_request = stub_captcha_verification
      solve_captcha
      post "/session/login-code.json", params: honeypot_magic(email:)
      code = emailed_code

      expect {
        post "/session/login-code/verify.json",
             params: {
               email:,
               code:,
               username: "chosen_username",
             }
      }.to change(User, :count).by(1)

      expect(response.parsed_body["account_created"]).to eq(true)
      expect(verification_request).to have_been_requested.once
    end

    it "creates an approval account without a second challenge" do
      SiteSetting.must_approve_users = true
      verification_request = stub_captcha_verification
      solve_captcha
      post "/session/login-code.json", params: honeypot_magic(email:)
      code = emailed_code

      post "/session/login-code/verify.json", params: { email:, code: }
      signup_token = response.parsed_body["signup_token"]

      expect {
        post "/session/login-code/verify.json",
             params: {
               signup_token:,
               username: "approval-person",
             }
      }.to change(User, :count).by(1)

      expect(response.parsed_body).to eq("pending_approval" => true)
      expect(verification_request).to have_been_requested.once
    end

    context "when using reCAPTCHA v3" do
      before do
        SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V3
        SiteSetting.recaptcha_v3_site_key = "site-key"
        SiteSetting.recaptcha_v3_secret_key = "secret-key"
        stub_request(:post, DiscourseCaptcha::RecaptchaV3Provider::CAPTCHA_VERIFICATION_URL).with(
          body: hash_including(response: "captcha-token"),
        ).to_return(status: 200, body: '{"success":true,"score":0.9,"action":"signup"}')
      end

      it "stores the score from the code request on the account it creates" do
        post "/captcha/recaptcha_v3/create.json", params: { token: "captcha-token" }
        post "/session/login-code.json", params: honeypot_magic(email:)
        code = emailed_code

        post "/session/login-code/verify.json",
             params: {
               email:,
               code:,
               username: "chosen_username",
             }

        expect(
          User.find_by_email(email).custom_fields[DiscourseCaptcha::SignupScore::CUSTOM_FIELD],
        ).to eq("0.9")
      end

      it "stores the score from the code request on an approval account" do
        SiteSetting.must_approve_users = true
        post "/captcha/recaptcha_v3/create.json", params: { token: "captcha-token" }
        post "/session/login-code.json", params: honeypot_magic(email:)
        code = emailed_code

        post "/session/login-code/verify.json", params: { email:, code: }
        post "/session/login-code/verify.json",
             params: {
               signup_token: response.parsed_body["signup_token"],
               username: "approval-person",
             }

        expect(
          User.find_by_email(email).custom_fields[DiscourseCaptcha::SignupScore::CUSTOM_FIELD],
        ).to eq("0.9")
      end
    end
  end

  describe "#verify_login_code" do
    fab!(:existing_user, :user)

    before do
      SiteSetting.enable_local_logins_via_email = true
      SiteSetting.enable_local_logins_via_code = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "site-key"
      SiteSetting.hcaptcha_secret_key = "secret-key"
    end

    it "verifies the email without CAPTCHA and waits for a username before creating an account" do
      email = "new.person@example.com"
      login_code = EmailLoginCode.generate!(email:)

      expect {
        post "/session/login-code/verify.json", params: { email:, code: login_code.code }
      }.not_to change(User, :count)

      expect(response.status).to eq(200)
      expect(response.parsed_body["username_required"]).to eq(true)
      expect(login_code.reload.consumed_at).to be_nil
      expect(session[:current_user_id]).to be_nil
    end

    it "does not create an account without completing CAPTCHA" do
      email = "new.person@example.com"
      code = EmailLoginCode.generate!(email:).code

      expect {
        post "/session/login-code/verify.json",
             params: {
               email:,
               code:,
               username: "chosen_username",
             }
      }.not_to change(User, :count)

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(session[:current_user_id]).to be_nil
    end

    it "requires CAPTCHA on final generated-username creation without consuming the code" do
      plugin_instance = Plugin::Instance.new
      modifier = proc { |_, _, _| :generated }
      plugin_instance.register_modifier(:email_login_code_username_mode, &modifier)
      email = "new.person@example.com"
      login_code = EmailLoginCode.generate!(email:)

      post "/session/login-code/verify.json", params: { email:, code: login_code.code }
      username = response.parsed_body["username"]

      expect(response.parsed_body["generated_username"]).to eq(true)
      expect(User.find_by_email(email)).to be_nil

      post "/session/login-code/verify.json", params: { email:, code: login_code.code, username: }

      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(User.find_by_email(email)).to be_nil
      expect(login_code.reload.consumed_at).to be_nil
    ensure
      if plugin_instance && modifier
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :email_login_code_username_mode,
          &modifier
        )
      end
    end

    it "creates an account after the CAPTCHA provider verifies the challenge" do
      email = "new.person@example.com"
      code = EmailLoginCode.generate!(email:).code
      stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
        body: {
          secret: SiteSetting.hcaptcha_secret_key,
          response: "captcha-token",
        },
      ).to_return(status: 200, body: '{"success":true}')

      post "/captcha/hcaptcha/create.json", params: { token: "captcha-token" }

      expect {
        post "/session/login-code/verify.json",
             params: {
               email:,
               code:,
               username: "chosen_username",
             }
      }.to change(User, :count).by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["account_created"]).to eq(true)
      expect(session[:current_user_id]).to eq(User.find_by_email(email).id)
    end

    it "accepts an invitation without CAPTCHA" do
      invite = Fabricate(:invite, email: "invited@example.com")
      code = EmailLoginCode.generate!(email: invite.email).code

      expect {
        post "/session/login-code/verify.json",
             params: {
               email: invite.email,
               code:,
               username: "invited_person",
               invite_key: invite.invite_key,
             }
      }.to change(User, :count).by(1)

      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(User.find_by_email(invite.email).id)
    end

    it "logs in an existing account without CAPTCHA" do
      code = EmailLoginCode.generate!(email: existing_user.email).code

      post "/session/login-code/verify.json", params: { email: existing_user.email, code: }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("user", "username")).to eq(existing_user.username)
      expect(session[:current_user_id]).to eq(existing_user.id)
    end

    context "when using reCAPTCHA v3" do
      let(:email) { "new.person@example.com" }
      let(:login_code) { EmailLoginCode.generate!(email:) }

      before do
        SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V3
        SiteSetting.recaptcha_v3_site_key = "site-key"
        SiteSetting.recaptcha_v3_secret_key = "secret-key"
        stub_request(:post, DiscourseCaptcha::RecaptchaV3Provider::CAPTCHA_VERIFICATION_URL).with(
          body: hash_including(response: "captcha-token"),
        ).to_return(status: 200, body: '{"success":true,"score":0.9,"action":"signup"}')
      end

      it "stores the signup score on the account created from a login code" do
        post "/captcha/recaptcha_v3/create.json", params: { token: "captcha-token" }
        post "/session/login-code/verify.json",
             params: {
               email:,
               code: login_code.code,
               username: "chosen_username",
             }

        expect(response.parsed_body["account_created"]).to eq(true)
        expect(
          User.find_by_email(email).custom_fields[DiscourseCaptcha::SignupScore::CUSTOM_FIELD],
        ).to eq("0.9")
      end

      it "does not carry the score of a failed signup over to another account" do
        allow_any_instance_of(ActionDispatch::Executor).to receive(:call) do |middleware, env|
          middleware.instance_variable_get(:@app).call(env)
        end
        Fabricate(:user, username: "chosen_username")

        post "/captcha/recaptcha_v3/create.json", params: { token: "captcha-token" }
        post "/session/login-code/verify.json",
             params: {
               email:,
               code: login_code.code,
               username: "chosen_username",
             }

        expect(User.find_by_email(email)).to be_nil
        expect(
          Fabricate(:user).custom_fields[DiscourseCaptcha::SignupScore::CUSTOM_FIELD],
        ).to be_nil
      ensure
        DiscourseCaptcha::SignupScore.reset
      end

      it "stores the signup score on the account created after approval signup details" do
        SiteSetting.must_approve_users = true
        post "/session/login-code/verify.json", params: { email:, code: login_code.code }
        signup_token = response.parsed_body["signup_token"]

        post "/captcha/recaptcha_v3/create.json", params: { token: "captcha-token" }
        post "/session/login-code/verify.json",
             params: {
               signup_token:,
               username: "approval-person",
               name: "Approval Person",
             }

        expect(response.parsed_body).to eq("pending_approval" => true)
        expect(
          User.find_by_email(email).custom_fields[DiscourseCaptcha::SignupScore::CUSTOM_FIELD],
        ).to eq("0.9")
      end
    end

    context "when an approval signup requires account details" do
      fab!(:user_field, :user_field)

      before do
        Jobs.run_immediately!
        SiteSetting.must_approve_users = true
        SiteSetting.full_name_requirement = "required_at_signup"
      end

      let(:email) { "approval.person@example.com" }
      let(:login_code) { EmailLoginCode.generate!(email:) }
      let(:account_details) do
        {
          username: "approval-person",
          name: "Approval Person",
          user_fields: {
            user_field.id.to_s => "Developer",
          },
        }
      end

      it "verifies CAPTCHA only when submitting the approval account details" do
        verification_request =
          stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.hcaptcha_secret_key,
              response: "captcha-token",
            },
          ).to_return(status: 200, body: '{"success":true}')

        expect {
          post "/session/login-code/verify.json", params: { email:, code: login_code.code }
        }.not_to change(User, :count)
        signup_token = response.parsed_body["signup_token"]

        expect(signup_token).to be_present
        expect(verification_request).not_to have_been_requested
        expect(login_code.reload.consumed_at).to be_nil

        post "/captcha/hcaptcha/create.json", params: { token: "captcha-token" }

        expect {
          post "/session/login-code/verify.json",
               params: account_details.merge(signup_token: signup_token)
        }.to change(User, :count).by(1).and change(ReviewableUser, :count).by(1)

        expect(response.parsed_body).to eq("pending_approval" => true)
        expect(verification_request).to have_been_requested.once
      end

      it "requires valid CAPTCHA on the final request before creating the approval account" do
        post "/session/login-code/verify.json", params: { email:, code: login_code.code }
        signup_token = response.parsed_body["signup_token"]

        expect {
          post "/session/login-code/verify.json",
               params: account_details.merge(signup_token: signup_token)
        }.not_to change(User, :count)
        expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
        expect(ReviewableUser.count).to eq(0)
        expect(login_code.reload.consumed_at).to be_nil

        stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
          body: hash_including(response: "bad-token"),
        ).to_return(status: 200, body: '{"success":false}')
        post "/captcha/hcaptcha/create.json", params: { token: "bad-token" }
        post "/session/login-code/verify.json",
             params: account_details.merge(signup_token: signup_token)

        expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
        expect(User.find_by_email(email)).to be_nil
        expect(ReviewableUser.count).to eq(0)
        expect(login_code.reload.consumed_at).to be_nil

        stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
          body: hash_including(response: "valid-token"),
        ).to_return(status: 200, body: '{"success":true}')
        post "/captcha/hcaptcha/create.json", params: { token: "valid-token" }

        expect {
          post "/session/login-code/verify.json",
               params: account_details.merge(signup_token: signup_token)
        }.to change(User, :count).by(1).and change(ReviewableUser, :count).by(1)

        expect(response.parsed_body).to eq("pending_approval" => true)
        expect(login_code.reload.consumed_at).to be_present
      end
    end

    context "when signup requires user fields" do
      fab!(:user_field, :user_field)

      it "retains the CAPTCHA token until the required fields are submitted" do
        email = "new.person@example.com"
        code = EmailLoginCode.generate!(email:).code

        expect { post "/session/login-code/verify.json", params: { email:, code: } }.not_to change(
          User,
          :count,
        )
        expect(response.parsed_body["user_fields_required"]).to eq(true)

        stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).to_return(
          status: 200,
          body: '{"success":true}',
        )
        post "/captcha/hcaptcha/create.json", params: { token: "captcha-token" }

        expect {
          post "/session/login-code/verify.json",
               params: {
                 email:,
                 code:,
                 username: "chosen_username",
                 user_fields: {
                   user_field.id.to_s => "Developer",
                 },
               }
        }.to change(User, :count).by(1)
      end
    end
  end
end
