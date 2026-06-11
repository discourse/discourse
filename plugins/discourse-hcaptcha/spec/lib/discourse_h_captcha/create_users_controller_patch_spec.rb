# frozen_string_literal: true

RSpec.describe "Users", type: :request do
  describe "POST /u" do
    let(:user_params) do
      honeypot_magic(
        {
          email: "awesomeunicorn@discourse.org",
          username: "awesomeunicorn",
          password: "P4ssw0rd$$",
        },
      )
    end

    before do
      SiteSetting.enable_local_logins = true
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::NONE

      SiteSetting.same_site_cookies = "Lax"

      SiteSetting.hcaptcha_site_key = "site-key"
      SiteSetting.hcaptcha_secret_key = "secret-key"

      SiteSetting.recaptcha_site_key = "site-key"
      SiteSetting.recaptcha_secret_key = "secret-key"

      stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
        body: {
          secret: SiteSetting.hcaptcha_secret_key,
          response: "token-from-hCaptcha",
        },
      ).to_return(status: 200, body: '{"success":true}', headers: {})
    end

    context "when captcha verification fails" do
      context "when using hCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
          stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
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

      context "when using reCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

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
    end

    context "when captcha token is missing" do
      context "when using hCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
        end

        it "fails registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end

      context "when using reCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA
        end

        it "fails registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end
    end

    context "when captcha verification is successful" do
      context "when using hCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA

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

      context "when using reCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

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

      context "when site is login-required" do
        before do
          SiteSetting.login_required = true
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
        end

        it "succeeds in registration" do
          post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
          post "/u.json", params: user_params

          expect(JSON.parse(response.body)["success"]).to be(true)
        end
      end
    end

    context "when captcha is disabled" do
      before { SiteSetting.discourse_captcha_enabled = false }

      it "succeeds in registration" do
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(true)
      end
    end

    context "when captcha provider is set to none" do
      before { SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::NONE }

      it "succeeds in registration without captcha" do
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(true)
      end
    end

    context "when captcha is misconfigured" do
      context "when hCaptcha is selected but keys are missing" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
          SiteSetting.hcaptcha_site_key = ""
          SiteSetting.hcaptcha_secret_key = ""
        end

        it "blocks registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
          expect(JSON.parse(response.body)["message"]).to include("not properly configured")
        end
      end

      context "when reCaptcha is selected but keys are missing" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA
          SiteSetting.recaptcha_site_key = ""
          SiteSetting.recaptcha_secret_key = ""
        end

        it "blocks registration" do
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
          expect(JSON.parse(response.body)["message"]).to include("not properly configured")
        end
      end
    end

    context "when captcha provider returns server error" do
      context "when using hCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA

          stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.hcaptcha_secret_key,
              response: "token-from-hCaptcha",
            },
          ).to_return(status: 500, body: "Internal Server Error")
        end

        it "fails registration" do
          post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end

      context "when using reCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

          stub_request(:post, DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.recaptcha_secret_key,
              response: "token-from-reCaptcha",
            },
          ).to_return(status: 503, body: "Service Unavailable")
        end

        it "fails registration" do
          post "/captcha/recaptcha/create.json", params: { token: "token-from-reCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end
    end

    context "when captcha provider returns malformed response" do
      context "when using hCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA

          stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.hcaptcha_secret_key,
              response: "token-from-hCaptcha",
            },
          ).to_return(status: 200, body: "not valid json")
        end

        it "fails registration" do
          post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end

      context "when using reCaptcha" do
        before do
          SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA

          stub_request(:post, DiscourseHcaptcha::RecaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
            body: {
              secret: SiteSetting.recaptcha_secret_key,
              response: "token-from-reCaptcha",
            },
          ).to_return(status: 200, body: "not valid json")
        end

        it "fails registration" do
          post "/captcha/recaptcha/create.json", params: { token: "token-from-reCaptcha" }
          post "/u.json", params: user_params
          expect(JSON.parse(response.body)["success"]).to be(false)
        end
      end
    end

    context "when captcha response has success field as nil" do
      before do
        SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA

        stub_request(:post, DiscourseHcaptcha::HcaptchaProvider::CAPTCHA_VERIFICATION_URL).with(
          body: {
            secret: SiteSetting.hcaptcha_secret_key,
            response: "token-from-hCaptcha",
          },
        ).to_return(status: 200, body: '{"error-codes":["missing-input-secret"]}')
      end

      it "fails registration" do
        post "/captcha/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(false)
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
