# frozen_string_literal: true

RSpec.describe DiscourseHcaptcha::RecaptchaProvider do
  subject(:provider) { described_class.new }

  describe "#captcha_verification_url" do
    it "returns the reCAPTCHA verification URL" do
      expect(provider.captcha_verification_url).to eq(
        "https://www.google.com/recaptcha/api/siteverify",
      )
    end
  end

  describe "#fetch_captcha_token" do
    let(:temp_id) { SecureRandom.uuid }
    let(:token) { "test-recaptcha-token" }
    let(:request) { ActionDispatch::TestRequest.create }
    let(:cookies) { ActionDispatch::Cookies::CookieJar.build(request, {}) }

    before do
      Discourse.redis.setex("reCaptchaToken_#{temp_id}", 120, token)
      cookies.encrypted[:re_captcha_temp_id] = temp_id
    end

    it "retrieves token from Redis" do
      result = provider.fetch_captcha_token(cookies)
      expect(result).to eq(token)
    end

    it "deletes the token from Redis after fetching" do
      provider.fetch_captcha_token(cookies)
      expect(Discourse.redis.get("reCaptchaToken_#{temp_id}")).to be_nil
    end

    it "deletes the cookie after fetching" do
      provider.fetch_captcha_token(cookies)
      expect(cookies.encrypted[:re_captcha_temp_id]).to be_nil
    end

    context "when no cookie is present" do
      let(:empty_cookies) { ActionDispatch::Cookies::CookieJar.build(request, {}) }

      it "returns nil" do
        result = provider.fetch_captcha_token(empty_cookies)
        expect(result).to be_nil
      end
    end
  end

  describe "#send_captcha_verification" do
    let(:token) { "test-recaptcha-token" }

    before do
      SiteSetting.enable_local_logins = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

      SiteSetting.recaptcha_site_key = "site-key"
      SiteSetting.recaptcha_secret_key = "secret-key"
    end

    it "returns the response from reCAPTCHA" do
      stub =
        stub_request(
          :post,
          DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL,
        ).to_return(
          status: 200,
          body: '{"success":true,"challenge_ts":"2024-01-01T00:00:00Z","hostname":"example.com"}',
        )

      response = provider.send_captcha_verification(token)

      expect(stub).to have_been_requested

      expect(response.code.to_i).to eq(200)
      expect(JSON.parse(response.body)["success"]).to be(true)
    end
  end
end
