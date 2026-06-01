# frozen_string_literal: true

RSpec.describe DiscourseHcaptcha::RecaptchaController do
  describe "POST /captcha/recaptcha/create" do
    before do
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA
      SiteSetting.recaptcha_site_key = "test-site-key"
      SiteSetting.recaptcha_secret_key = "test-secret-key"
    end

    context "when reCaptcha is enabled and configured" do
      it "stores token in Redis and sets encrypted cookie" do
        post "/captcha/recaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
        expect(response.cookies["re_captcha_temp_id"]).to be_present
      end

      it "stores token in Redis" do
        post "/captcha/recaptcha/create.json", params: { token: "test-token" }

        keys = Discourse.redis.keys("reCaptchaToken_*")
        expect(keys).not_to be_empty

        stored_token = Discourse.redis.get(keys.first)
        expect(stored_token).to eq("test-token")
      end
    end

    context "when token is missing" do
      it "returns 400 error" do
        post "/captcha/recaptcha/create.json", params: {}

        expect(response.status).to eq(400)
      end

      it "returns 400 error when token is blank" do
        post "/captcha/recaptcha/create.json", params: { token: "" }

        expect(response.status).to eq(400)
      end
    end

    context "when reCaptcha is not the selected provider" do
      before do
        SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
        SiteSetting.hcaptcha_site_key = "test-site-key"
        SiteSetting.hcaptcha_secret_key = "test-secret-key"
      end

      it "returns 404 error" do
        post "/captcha/recaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end

    context "when captcha provider is none" do
      before { SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::NONE }

      it "returns 404 error" do
        post "/captcha/recaptcha/create.json", params: { token: "test-token" }

        expect(response.status).to eq(404)
      end
    end
  end
end
