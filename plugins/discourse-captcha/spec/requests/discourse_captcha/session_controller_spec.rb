# frozen_string_literal: true

RSpec.describe SessionController do
  describe "POST /session/login-code/verify" do
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

    it "creates an account after completing CAPTCHA" do
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
  end
end
