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
      SiteSetting.discourse_hcaptcha_enabled = true
      SiteSetting.same_site_cookies = "Lax"
      SiteSetting.hcaptcha_secret_key = "secret-key"

      stub_request(:post, "https://hcaptcha.com/siteverify").with(
        body: {
          secret: SiteSetting.hcaptcha_secret_key,
          response: "token-from-hCaptcha",
        },
      ).to_return(status: 200, body: '{"success":true}', headers: {})
    end

    context "when h_captcha verification fails" do
      before do
        stub_request(:post, "https://hcaptcha.com/siteverify").with(
          body: {
            secret: SiteSetting.hcaptcha_secret_key,
            response: "token-from-hCaptcha",
          },
        ).to_return(status: 200, body: '{"success":false}', headers: {})
      end

      it "fails registration" do
        post "/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(false)
      end
    end

    context "when h_captcha token is missing" do
      it "fails registration" do
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(false)
      end
    end

    context "when h_captcha verification is successful" do
      it "succeeds in registration" do
        post "/hcaptcha/create.json", params: { token: "token-from-hCaptcha" }
        post "/u.json", params: user_params
        expect(JSON.parse(response.body)["success"]).to be(true)
      end
    end

    context "when h_captcha is disabled" do
      before { SiteSetting.discourse_hcaptcha_enabled = false }

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
