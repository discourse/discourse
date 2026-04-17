# frozen_string_literal: true

RSpec.describe DiscourseHcaptcha::RecaptchaProvider do
  subject(:provider) { described_class.new }

  describe "#captcha_verification_url" do
    it "returns the reCAPTCHA verification URL" do
      expect(provider.captcha_verification_url).to eq(
        "https://www.google.com/recaptcha/api/siteverify"
      )
    end
  end

  describe "#fetch_captcha_token" do
    let(:token) { "test-recaptcha-token" }
    let(:server_session) { ServerSession.new(SecureRandom.hex) }

    before { server_session["recaptcha_token"] = token }

    it "retrieves token from server session" do
      result = provider.fetch_captcha_token(server_session)
      expect(result).to eq(token)
    end

    it "deletes the token from server session after fetching" do
      provider.fetch_captcha_token(server_session)
      expect(server_session["recaptcha_token"]).to be_nil
    end

    context "when no token is present" do
      let(:empty_session) { ServerSession.new(SecureRandom.hex) }

      it "returns nil" do
        result = provider.fetch_captcha_token(empty_session)
        expect(result).to be_nil
      end
    end
  end

  describe "#send_captcha_verification" do
    let(:token) { "test-recaptcha-token" }

    before do
      SiteSetting.enable_local_logins = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider =
        DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

      SiteSetting.recaptcha_site_key = "site-key"
      SiteSetting.recaptcha_secret_key = "secret-key"
    end

    it "returns the response from reCAPTCHA" do
      stub =
        stub_request(
          :post,
          DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL
        ).to_return(
          status: 200,
          body:
            '{"success":true,"challenge_ts":"2024-01-01T00:00:00Z","hostname":"example.com"}'
        )

      response = provider.send_captcha_verification(token)

      expect(stub).to have_been_requested

      expect(response.code.to_i).to eq(200)
      expect(JSON.parse(response.body)["success"]).to be(true)
    end
  end
end
