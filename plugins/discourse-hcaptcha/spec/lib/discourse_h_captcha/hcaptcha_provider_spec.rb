# frozen_string_literal: true

RSpec.describe DiscourseHcaptcha::HcaptchaProvider do
  subject(:provider) { described_class.new }

  describe "#captcha_verification_url" do
    it "returns the hCaptcha verification URL" do
      expect(provider.captcha_verification_url).to eq("https://hcaptcha.com/siteverify")
    end
  end

  describe "#fetch_captcha_token" do
    let(:token) { "test-hcaptcha-token" }
    let(:server_session) { ServerSession.new(SecureRandom.hex) }

    before { server_session["hcaptcha_token"] = token }

    it "retrieves token from server session" do
      result = provider.fetch_captcha_token(server_session)
      expect(result).to eq(token)
    end

    it "deletes the token from server session after fetching" do
      provider.fetch_captcha_token(server_session)
      expect(server_session["hcaptcha_token"]).to be_nil
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
    let(:token) { "test-hcaptcha-token" }

    before { SiteSetting.hcaptcha_secret_key = "test-secret-key" }

    it "returns the response from hCaptcha" do
      stub =
        stub_request(:post, "https://hcaptcha.com/siteverify").to_return(
          status: 200,
          body: '{"success":true}',
        )

      response = provider.send_captcha_verification(token)

      expect(stub).to have_been_requested

      expect(response.code.to_i).to eq(200)
      expect(JSON.parse(response.body)["success"]).to be(true)
    end
  end
end
