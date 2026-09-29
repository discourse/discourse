# frozen_string_literal: true

RSpec.describe DiscourseCaptcha::AdminCaptchaController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before do
    SiteSetting.discourse_captcha_provider = "recaptcha"
    SiteSetting.recaptcha_site_key = "test-site-key"
    SiteSetting.recaptcha_secret_key = "test-secret-key"
  end

  describe "#show" do
    it "returns the public configuration while enforcement is disabled" do
      sign_in(admin)
      SiteSetting.discourse_captcha_enabled = false

      get "/admin/plugins/discourse-captcha/test.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "provider" => "recaptcha",
        "site_key" => SiteSetting.recaptcha_site_key,
        "configured" => true,
      )
      expect(response.body).not_to include(SiteSetting.recaptcha_secret_key)
    end

    it "supports directly loading the test page" do
      sign_in(admin)

      get "/admin/plugins/discourse-captcha/test"

      expect(response.status).to eq(200)
    end

    it "identifies missing credentials" do
      sign_in(admin)
      SiteSetting.recaptcha_secret_key = ""

      get "/admin/plugins/discourse-captcha/test.json"

      expect(response.parsed_body["configured"]).to eq(false)
    end

    it "denies anonymous users, regular users, and moderators" do
      get "/admin/plugins/discourse-captcha/test.json"
      expect(response.status).to eq(404)

      [user, moderator].each do |actor|
        sign_in(actor)
        get "/admin/plugins/discourse-captcha/test.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#verify" do
    let(:params) { { token: "test-token", provider: "recaptcha", site_key: "test-site-key" } }
    let(:verification_url) { "https://www.google.com/recaptcha/api/siteverify" }

    it "verifies the saved keys without creating an account or storing a signup token" do
      sign_in(admin)
      SiteSetting.discourse_captcha_enabled = false
      stub_request(:post, verification_url).with(
        body: {
          secret: "test-secret-key",
          response: "test-token",
        },
      ).to_return(status: 200, body: { success: true }.to_json)

      expect { post "/admin/plugins/discourse-captcha/test.json", params: params }.not_to change(
        User,
        :count,
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(server_session["recaptcha_token"]).to be_nil
      expect(SiteSetting.discourse_captcha_enabled).to eq(false)
    end

    it "verifies hCaptcha with its saved secret" do
      sign_in(admin)
      SiteSetting.discourse_captcha_provider = "hcaptcha"
      SiteSetting.hcaptcha_site_key = "test-site-key"
      SiteSetting.hcaptcha_secret_key = "hcaptcha-secret"
      stub_request(:post, "https://hcaptcha.com/siteverify").with(
        body: {
          secret: "hcaptcha-secret",
          response: "test-token",
        },
      ).to_return(status: 200, body: { success: true }.to_json)

      post "/admin/plugins/discourse-captcha/test.json", params: params.merge(provider: "hcaptcha")

      expect(response.parsed_body["success"]).to eq(true)
    end

    it "explains a rejected secret without disclosing it" do
      sign_in(admin)
      stub_request(:post, verification_url).to_return(
        status: 200,
        body: { :success => false, "error-codes" => ["invalid-input-secret"] }.to_json,
      )

      post "/admin/plugins/discourse-captcha/test.json", params: params

      expect(response.parsed_body).to eq(
        "success" => false,
        "message" => I18n.t("discourse_captcha.configuration_test.errors.invalid_secret"),
      )
      expect(response.body).not_to include(SiteSetting.recaptcha_secret_key)
    end

    it "handles expired challenges" do
      sign_in(admin)
      stub_request(:post, verification_url).to_return(
        status: 200,
        body: { :success => false, "error-codes" => ["timeout-or-duplicate"] }.to_json,
      )

      post "/admin/plugins/discourse-captcha/test.json", params: params

      expect(response.parsed_body["message"]).to eq(
        I18n.t("discourse_captcha.configuration_test.errors.expired"),
      )
    end

    it "handles unavailable providers and malformed responses" do
      sign_in(admin)
      [
        { status: 503, body: "unavailable" },
        { status: 200, body: "invalid json" },
        { status: 200, body: "[]" },
        { status: 200, body: { success: "true" }.to_json },
      ].each do |provider_response|
        stub_request(:post, verification_url).to_return(**provider_response)

        post "/admin/plugins/discourse-captcha/test.json", params: params

        expect(response.parsed_body["success"]).to eq(false)
      end
    end

    it "handles a connection timeout" do
      sign_in(admin)
      stub_request(:post, verification_url).to_timeout

      post "/admin/plugins/discourse-captcha/test.json", params: params

      expect(response.parsed_body["message"]).to eq(
        I18n.t("discourse_captcha.configuration_test.errors.unavailable"),
      )
    end

    it "rejects missing tokens and changed configurations" do
      sign_in(admin)
      post "/admin/plugins/discourse-captcha/test.json", params: params.except(:token)
      expect(response.status).to eq(400)

      post "/admin/plugins/discourse-captcha/test.json", params: params.merge(provider: "hcaptcha")
      expect(response.status).to eq(400)

      post "/admin/plugins/discourse-captcha/test.json", params: params.merge(site_key: "old-key")
      expect(response.status).to eq(400)
    end

    it "reports missing credentials and no selected provider" do
      sign_in(admin)
      SiteSetting.recaptcha_secret_key = ""
      post "/admin/plugins/discourse-captcha/test.json", params: params
      expect(response.parsed_body["success"]).to eq(false)

      SiteSetting.discourse_captcha_provider = "none"
      post "/admin/plugins/discourse-captcha/test.json",
           params: params.merge(provider: "none", site_key: nil)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "denies anonymous users, regular users, and moderators" do
      post "/admin/plugins/discourse-captcha/test.json", params: params
      expect(response.status).to eq(404)

      [user, moderator].each do |actor|
        sign_in(actor)
        post "/admin/plugins/discourse-captcha/test.json", params: params
        expect(response.status).to eq(404)
      end
    end
  end
end
