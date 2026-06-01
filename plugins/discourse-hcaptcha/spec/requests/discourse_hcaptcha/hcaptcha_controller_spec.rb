# frozen_string_literal: true

RSpec.describe DiscourseHcaptcha::HcaptchaController do
  describe "POST /captcha/hcaptcha/create" do
    before do
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "test-site-key"
      SiteSetting.hcaptcha_secret_key = "test-secret-key"
    end

    context "when hCaptcha is enabled and configured" do
      it "stores token in server session with 2 minute TTL" do
        post "/captcha/hcaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
        expect(server_session["hcaptcha_token"]).to eq("test-token")
        expect(server_session.ttl("hcaptcha_token")).to be_between(1, 120)
      end
    end

    context "when token is missing" do
      it "returns 400 error" do
        post "/captcha/hcaptcha/create.json", params: {}

        expect(response.status).to eq(400)
      end

      it "returns 400 error when token is blank" do
        post "/captcha/hcaptcha/create.json", params: { token: "" }

        expect(response.status).to eq(400)
      end
    end

    context "when hCaptcha is not the selected provider" do
      before do
        SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA
        SiteSetting.recaptcha_site_key = "test-site-key"
        SiteSetting.recaptcha_secret_key = "test-secret-key"
      end

      it "returns 404 error" do
        post "/captcha/hcaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end

    context "when captcha provider is none" do
      before { SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::NONE }

      it "returns 404 error" do
        post "/captcha/hcaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end
  end
end
