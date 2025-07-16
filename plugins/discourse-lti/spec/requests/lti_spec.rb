# frozen_string_literal: true

require "rails_helper"

describe "LTI Plugin" do
  let(:authorize_url) { "https://example.com/authorize" }
  let(:platform_private_key) { OpenSSL::PKey::RSA.generate 2048 }
  let(:platform_public_key) { platform_private_key.public_key }
  let(:platform_issuer_id) { "https://example.com" }
  let(:tool_client_id) { "toolclientid" }

  let(:init_params) do
    {
      iss: platform_issuer_id,
      login_hint: "loginhint",
      target_link_uri: "/t/123",
      lti_message_hint: "messagehint",
    }
  end

  before do
    SiteSetting.lti_enabled = true
    SiteSetting.lti_authorization_endpoint = authorize_url
    SiteSetting.lti_platform_public_key = platform_public_key.to_s
    SiteSetting.lti_platform_issuer_id = platform_issuer_id
    SiteSetting.lti_client_ids = tool_client_id
    SiteSetting.lti_email_verified = true
  end

  it "shows an error if auth is started on Discourse side" do
    post "/auth/lti"
    expect(response.status).to eq(302)
    expect(response.location).to eq("/auth/failure?message=third_party_only&strategy=lti")
  end

  describe "#initiate" do
    it "works with GET" do
      get "/auth/lti/initiate", params: init_params
      expect(response.status).to eq(302)
      expect(response.location).to start_with(authorize_url)
      expect(response.location).to include(
        tool_client_id,
        "loginhint",
        "messagehint",
        "state=",
        "nonce=",
      )
    end

    it "converts cross-site POST to same-site POST" do
      # We use SameSite=None session cookies, so the browser will not send them
      # in a cross-site POST. To work around this, we render a form with all the
      # same params, then auto-submit it. This ensures the correct session cookie
      # will be sent by the browser
      post "/auth/lti/initiate", params: init_params
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/html; charset=UTF-8")
      expect(response.body).to include '<form method="post">',
              "<input type='hidden' name='samesite' value='true'/>",
              "<input type='hidden' name='iss' value='#{Rack::Utils.escape_html(platform_issuer_id)}'/>",
              "<input type='hidden' name='login_hint' value='loginhint'/>",
              "<input type='hidden' name='lti_message_hint' value='messagehint'/>"
    end

    it "works with POST" do
      post "/auth/lti/initiate", params: init_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to start_with(authorize_url)
      expect(response.location).to include(
        tool_client_id,
        "loginhint",
        "messagehint",
        "state=",
        "nonce=",
      )
    end

    it "verifies the client_id if present" do
      get "/auth/lti/initiate", params: init_params.merge(client_id: tool_client_id)
      expect(response.status).to eq(302)
      expect(response.location).to start_with(authorize_url)

      get "/auth/lti/initiate", params: init_params.merge(client_id: "incorrect_client_id")
      expect(response.status).to eq(302)
      expect(response.location).to include("message=invalid_client_id")
    end

    it "requires client_id parameter if multiple are configured" do
      SiteSetting.lti_client_ids = "#{tool_client_id}|anotherkey"
      get "/auth/lti/initiate", params: init_params
      expect(response.status).to eq(302)
      expect(response.location).to include("message=missing_client_id")
    end

    it "verifies the client_id if multiple are configured" do
      SiteSetting.lti_client_ids = "#{tool_client_id}|anotherkey"
      get "/auth/lti/initiate", params: init_params.merge(client_id: "anotherkey")
      expect(response.status).to eq(302)
      expect(response.location).to start_with(authorize_url)
    end
  end

  describe "#callback" do
    let(:initialize_response) do
      get "/auth/lti/initiate", params: init_params
      expect(response.status).to eq(302)
      response.location
    end
    let(:state) { initialize_response[/state=([a-z0-9]+)/, 1] }
    let(:nonce) { initialize_response[/nonce=([a-z0-9]+)/, 1] }

    let(:token_data) do
      {
        sub: "myuid",
        iss: platform_issuer_id,
        nonce: nonce,
        exp: 1.hour.from_now.to_i,
        aud: tool_client_id,
        email: "email@example.com",
      }
    end
    let(:id_token) { JWT.encode(token_data, platform_private_key, "RS256") }

    let(:callback_params) { { id_token: id_token, state: state } }

    it "converts cross-site POST to same-site POST" do
      post "/auth/lti/callback", params: callback_params
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/html; charset=UTF-8")
      expect(response.body).to include '<form method="post">',
              "<input type='hidden' name='samesite' value='true'/>",
              "<input type='hidden' name='id_token' value='#{Rack::Utils.escape_html(id_token)}'/>",
              "<input type='hidden' name='state' value='#{state}'/>"
    end

    it "works correctly" do
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/t/123")
      data = JSON.parse(cookies[:authentication_data])
      expect(data["email"]).to eq("email@example.com")
    end

    it "works without PEM prefix/suffix" do
      SiteSetting.lti_platform_public_key =
        SiteSetting.lti_platform_public_key.gsub(/^-.*-$/) { "" }.strip

      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/t/123")
      data = JSON.parse(cookies[:authentication_data])
      expect(data["email"]).to eq("email@example.com")
    end

    it "fails if state does not match" do
      callback_params[:state] = "blah"
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/auth/failure?message=state_mismatch")
    end

    it "fails if nonce does not match" do
      token_data[:nonce] = "blah"
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/auth/failure?message=nonce_mismatch")
    end

    it "fails if audience does not match" do
      token_data[:aud] = "blah"
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/auth/failure?message=token_invalid")
    end

    it "fails if signature is wrong" do
      different_certificate = OpenSSL::PKey::RSA.generate 2048
      callback_params[:id_token] = JWT.encode token_data, different_certificate, "RS256"
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/auth/failure?message=token_invalid")
    end

    it "fails if token expired" do
      token_data[:exp] = 1.hour.ago.to_i
      post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
      expect(response.status).to eq(302)
      expect(response.location).to include("/auth/failure?message=token_invalid")
    end

    context "with invite custom field" do
      let(:invite) { Invite.generate(Discourse.system_user) }
      before do
        token_data[DiscourseLti::CUSTOM_DATA_CLAIM] = {
          DiscourseLti::DISCOURSE_INVITE_KEYS.first => invite.link,
        }
      end

      it "redirects new users to the invite" do
        post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
        expect(response.status).to eq(302)
        expect(response.location).to include(invite.link)
        data = JSON.parse(cookies[:authentication_data])
        expect(data["email"]).to eq("email@example.com")
      end

      it "sends existing users to the launch URL" do
        Fabricate(:user, email: "email@example.com")
        post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
        expect(response.status).to eq(302)
        expect(response.location).to include("/t/123")
      end
    end

    context "when a user is already logged in" do
      before { sign_in Fabricate(:user) }

      it "automatically goes into auth_reconnect mode" do
        post "/auth/lti/callback", params: callback_params.merge(samesite: "true")
        expect(response.status).to eq(302)
        expect(response.location).to include("/associate/")
      end
    end
  end
end
