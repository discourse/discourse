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
