# frozen_string_literal: true

RSpec.describe DiscourseCaptcha::RecaptchaController do
  describe "POST /captcha/recaptcha_v2/create" do
    before do
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V2
      SiteSetting.recaptcha_v2_site_key = "test-site-key"
      SiteSetting.recaptcha_v2_secret_key = "test-secret-key"
    end

    context "when reCaptcha is enabled and configured" do
      it "stores token in server session with 2 minute TTL" do
        post "/captcha/recaptcha_v2/create.json", params: { token: "test-token" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
        expect(server_session["recaptcha_token"]).to eq("test-token")
        expect(server_session.ttl("recaptcha_token")).to be_between(1, 120)
      end
    end

    context "when token is missing" do
      it "returns 400 error" do
        post "/captcha/recaptcha_v2/create.json", params: {}

        expect(response.status).to eq(400)
      end

      it "returns 400 error when token is blank" do
        post "/captcha/recaptcha_v2/create.json", params: { token: "" }

        expect(response.status).to eq(400)
      end
    end

    it "accepts tokens from signup pages opened before the provider rename" do
      post "/captcha/recaptcha/create.json", params: { token: "existing-page-token" }

      expect(response.status).to eq(200)
      expect(server_session["recaptcha_token"]).to eq("existing-page-token")
    end

    context "when reCaptcha is not the selected provider" do
      before do
        SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::HCAPTCHA
        SiteSetting.hcaptcha_site_key = "test-site-key"
        SiteSetting.hcaptcha_secret_key = "test-secret-key"
      end

      it "returns 404 error" do
        post "/captcha/recaptcha_v2/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end

    context "when captcha provider is none" do
      before { SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::NONE }

      it "returns 404 error" do
        post "/captcha/recaptcha_v2/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end
  end
end
