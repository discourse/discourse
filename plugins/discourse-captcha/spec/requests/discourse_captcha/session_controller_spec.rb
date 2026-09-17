# frozen_string_literal: true

RSpec.describe SessionController do
  describe "POST /session/login-code/verify" do
    fab!(:existing_user, :user)

    before do
      SiteSetting.enable_local_logins_via_email = true
      SiteSetting.enable_local_logins_via_code = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "site-key"
      SiteSetting.hcaptcha_secret_key = "secret-key"
    end

    it "does not create an account without completing CAPTCHA" do
      email = "new.person@example.com"
      code = EmailLoginCode.generate!(email:).code

      expect { post "/session/login-code/verify.json", params: { email:, code: } }.not_to change(
        User,
        :count,
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("captcha_verification_failed"))
      expect(session[:current_user_id]).to be_nil
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

      expect { post "/session/login-code/verify.json", params: { email:, code: } }.to change(
        User,
        :count,
      ).by(1)

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

      it "carries verified CAPTCHA proof into the continuation without validating it twice" do
        verification_request =
          stub_request(:post, DiscourseCaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.hcaptcha_secret_key,
              response: "captcha-token",
            },
          ).to_return(status: 200, body: '{"success":true}')
        post "/captcha/hcaptcha/create.json", params: { token: "captcha-token" }

        expect {
          post "/session/login-code/verify.json", params: { email:, code: login_code.code }
        }.not_to change(User, :count)
        signup_token = response.parsed_body["signup_token"]

        expect(signup_token).to be_present
        expect(verification_request).to have_been_requested.once
        expect(login_code.reload.consumed_at).to be_nil

        expect {
          post "/session/login-code/verify.json",
               params: account_details.merge(signup_token: signup_token)
        }.to change(User, :count).by(1).and change(ReviewableUser, :count).by(1)

        expect(response.parsed_body).to eq("pending_approval" => true)
        expect(verification_request).to have_been_requested.once
      end

      it "requires CAPTCHA on the final request when the continuation has no CAPTCHA proof" do
        SiteSetting.discourse_captcha_enabled = false
        post "/session/login-code/verify.json", params: { email:, code: login_code.code }
        signup_token = response.parsed_body["signup_token"]
        SiteSetting.discourse_captcha_enabled = true

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
                 user_fields: {
                   user_field.id.to_s => "Developer",
                 },
               }
        }.to change(User, :count).by(1)
      end
    end
  end
end
