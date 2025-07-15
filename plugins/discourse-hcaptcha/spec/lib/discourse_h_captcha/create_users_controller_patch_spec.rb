# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  describe "POST /u" do
    let(:user_params) do
      honeypot_magic(
        {
          name: "unicorn",
          email: "awesomeunicorn@example.com",
          username: "awesomeunicorn",
          password: "P4ssw0rd$$",
        },
      )
    end

    before do
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_hcaptcha_enabled = true
      SiteSetting.discourse_recaptcha_enabled = false
      SiteSetting.same_site_cookies = "Lax"

      stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
        body: {
          secret: SiteSetting.hcaptcha_secret_key,
          response: "token-from-hCaptcha",
        },
      ).to_return(status: 200, body: '{"success":true}', headers: {})
    end

    context "when captcha verification fails" do
      context "when using h_captcha" do
        before do
          SiteSetting.hcaptcha_secret_key = "secret-key"
          stub_request(:post, "https://hcaptcha.com/siteverify").with(
            body: {
              secret: SiteSetting.hcaptcha_secret_key,
              response: "token-from-hCaptcha",
            },
          ).to_return(status: 200, body: '{"success":false}', headers: {})
        end

        it "fails registration" do
          post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end

      context "when using recaptcha" do
        before do
          stub_request(:post, DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.recaptcha_secret_key,
              response: "token-from-reCaptcha",
            },
          ).to_return(status: 200, body: '{"success":false}', headers: {})
        end

        it "fails registration" do
          post "/captcha/recaptcha/create.json", params: { token: "token-from-reCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end

      it "fails registration" do
        post "/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(false)
      end
    end

    context "when captcha token is missing" do
      context "when using h_captcha" do
        before do
          SiteSetting.discourse_hcaptcha_enabled = true
          SiteSetting.discourse_recaptcha_enabled = false
        end
        it "fails registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end
      context "when using h_captcha" do
        before do
          SiteSetting.discourse_recaptcha_enabled = true
          SiteSetting.discourse_hcaptcha_enabled = false
        end
        it "fails registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end
    end

    context "when captcha verification is successful" do
      context "when using h_captcha" do
        before do
          SiteSetting.discourse_hcaptcha_enabled = true
          SiteSetting.discourse_recaptcha_enabled = false
          stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              "response" => "token-from-hCaptcha",
              "secret" => SiteSetting.hcaptcha_secret_key,
            },
          ).to_return(status: 200, body: '{"success":true}', headers: {})
        end
        it "succeeds in registration" do
          post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(true)
        end
      end

      context "when using re_captcha" do
        before do
          SiteSetting.discourse_recaptcha_enabled = true
          SiteSetting.discourse_hcaptcha_enabled = false
          stub_request(:post, DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              "response" => "token-from-reCaptcha",
              "secret" => SiteSetting.recaptcha_secret_key,
            },
          ).to_return(status: 200, body: '{"success":true}', headers: {})
        end
        it "succeeds in registration" do
          post "/captcha/recaptcha/create.json", params: { token: "token-from-reCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(true)
        end
      end
    end

    context "when captcha is disabled" do
      before do
        SiteSetting.discourse_captcha_enabled = false
        SiteSetting.discourse_hcaptcha_enabled = true
      end

      it "succeeds in registration" do
        post "/u.json", params: user_params

        expect(JSON.parse(response.body)["success"]).to be(true)
      end
    end

    private

    def honeypot_magic(params)
      get "/session/hp.json"
      json = response.parsed_body
      params[:password_confirmation] = json["value"]
      params[:challenge] = json["challenge"].reverse
      params
    end
  end
end
