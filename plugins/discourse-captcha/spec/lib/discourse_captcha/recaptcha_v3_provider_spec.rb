# frozen_string_literal: true

RSpec.describe DiscourseCaptcha::RecaptchaV3Provider do
  subject(:provider) { described_class.new }

  let(:captcha_response) { Struct.new(:code, :body) }

  before do
    SiteSetting.discourse_captcha_enabled = true
    SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V3
    SiteSetting.recaptcha_v3_site_key = "site-key"
    SiteSetting.recaptcha_v3_secret_key = "secret-key"
    SiteSetting.recaptcha_v3_score_threshold = 0.5
  end

  describe "#captcha_verification_url" do
    it "returns the reCAPTCHA verification URL" do
      expect(provider.captcha_verification_url).to eq(
        "https://www.google.com/recaptcha/api/siteverify",
      )
    end
  end

  describe "#fetch_captcha_token" do
    let(:token) { "test-recaptcha-v3-token" }
    let(:server_session) { ServerSession.new(SecureRandom.hex) }

    before { server_session["recaptcha_v3_token"] = token }

    it "retrieves token from server session" do
      expect(provider.fetch_captcha_token(server_session)).to eq(token)
    end

    it "deletes the token from server session after fetching" do
      provider.fetch_captcha_token(server_session)
      expect(server_session["recaptcha_v3_token"]).to be_nil
    end

    context "when no token is present" do
      let(:empty_session) { ServerSession.new(SecureRandom.hex) }

      it "returns nil" do
        expect(provider.fetch_captcha_token(empty_session)).to be_nil
      end
    end
  end

  describe "#send_captcha_verification" do
    let(:token) { "test-recaptcha-v3-token" }

    it "returns the response from reCAPTCHA" do
      stub =
        stub_request(
          :post,
          DiscourseCaptcha::RecaptchaV3Provider::CAPTCHA_VERIFICATION_URL,
        ).to_return(status: 200, body: '{"success":true,"score":0.9,"action":"signup"}')

      response = provider.send_captcha_verification(token)

      expect(stub).to have_been_requested
      expect(response.code.to_i).to eq(200)
      expect(JSON.parse(response.body)["success"]).to be(true)
    end
  end

  describe "#validate_captcha_response" do
    it "accepts a response meeting the score threshold and action" do
      response = captcha_response.new(200, '{"success":true,"score":0.9,"action":"signup"}')

      expect { provider.validate_captcha_response(response) }.not_to raise_error
    end

    it "accepts a successful response without action or score (Google test keys)" do
      response = captcha_response.new(200, '{"success":true}')

      expect { provider.validate_captcha_response(response) }.not_to raise_error
    end

    it "rejects a response whose score is below the threshold" do
      response = captcha_response.new(200, '{"success":true,"score":0.2,"action":"signup"}')

      expect { provider.validate_captcha_response(response) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "rejects a response with a mismatched action" do
      response = captcha_response.new(200, '{"success":true,"score":0.9,"action":"login"}')

      expect { provider.validate_captcha_response(response) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "rejects an unsuccessful response" do
      response = captcha_response.new(200, '{"success":false}')

      expect { provider.validate_captcha_response(response) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "rejects a response returning a server error" do
      response = captcha_response.new(503, "Service Unavailable")

      expect { provider.validate_captcha_response(response) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end
  end
end
