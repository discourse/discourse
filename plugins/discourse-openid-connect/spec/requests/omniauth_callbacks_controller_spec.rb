# frozen_string_literal: true

describe Users::OmniauthCallbacksController do
  describe "#complete with an OIDC email claim" do
    fab!(:user)

    let(:document_url) { "https://id.example.com/.well-known/openid-configuration" }
    let(:userinfo) { { sub: "new-provider-uid", mail: user.email } }
    let(:document) do
      {
        issuer: "https://id.example.com",
        authorization_endpoint: "https://id.example.com/authorize",
        token_endpoint: "https://id.example.com/token",
        userinfo_endpoint: "https://id.example.com/userinfo",
      }
    end

    before do
      SiteSetting.openid_connect_discovery_document = document_url
      SiteSetting.openid_connect_client_id = "client-id"
      SiteSetting.openid_connect_client_secret = "client-secret"
      SiteSetting.openid_connect_enabled = true
      SiteSetting.openid_connect_email_claim = "mail"

      stub_request(:get, document_url).to_return(body: ->(_request) { document.to_json })
      stub_request(:get, "https://id.example.com/userinfo").to_return(
        body: ->(_request) { userinfo.to_json },
        headers: {
          "Content-Type" => "application/json",
        },
      )
    end

    after { Discourse.cache.delete("openid-connect-discovery-#{document_url}") }

    def authenticate(id_token_claims: {})
      post "/auth/oidc"
      params = Rack::Utils.parse_query(URI(response.location).query)
      token =
        JWT.encode(
          {
            iss: "https://id.example.com",
            sub: userinfo[:sub],
            aud: "client-id",
            exp: 5.minutes.from_now.to_i,
            iat: Time.now.to_i,
            nonce: params.fetch("nonce"),
            email: user.email,
            mail: user.email,
          }.merge(id_token_claims),
          nil,
          "none",
        )
      stub_request(:post, "https://id.example.com/token").to_return(
        body: { access_token: "access-token", token_type: "Bearer", id_token: token }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      get "/auth/oidc/callback", params: { code: "code", state: params.fetch("state") }
    end

    it "logs into the existing account and links the new provider identity" do
      authenticate

      expect(session[:current_user_id]).to eq(user.id)
      expect(
        UserAssociatedAccount.find_by(provider_name: "oidc", provider_uid: userinfo[:sub]).user_id,
      ).to eq(user.id)
    end

    it "replaces an old provider association when the verified email matches" do
      old_association =
        Fabricate(
          :user_associated_account,
          user: user,
          provider_name: "oidc",
          provider_uid: "old-provider-uid",
        )
      userinfo[:email_verified] = true
      authenticate

      expect(session[:current_user_id]).to eq(user.id)
      expect(UserAssociatedAccount.exists?(old_association.id)).to eq(false)
      expect(
        UserAssociatedAccount.find_by(provider_name: "oidc", user_id: user.id).provider_uid,
      ).to eq(userinfo[:sub])
    end

    it "reads the configured claim from the ID token when UserInfo is unavailable" do
      document.delete(:userinfo_endpoint)
      authenticate(id_token_claims: { email: "another@example.com" })

      expect(session[:current_user_id]).to eq(user.id)
    end

    it "uses the standard email claim by default" do
      SiteSetting.remove_override!(:openid_connect_email_claim)
      userinfo[:email] = userinfo.delete(:mail)
      authenticate

      expect(session[:current_user_id]).to eq(user.id)
    end

    it "uses the configured claim when a different standard email is also present" do
      userinfo[:email] = "another@example.com"
      authenticate

      expect(session[:current_user_id]).to eq(user.id)
    end

    it "leaves the account unlinked when email matching is disabled" do
      SiteSetting.openid_connect_match_by_email = false
      authenticate

      expect(session[:current_user_id]).to be_nil
      expect(
        UserAssociatedAccount.find_by(provider_name: "oidc", provider_uid: userinfo[:sub]).user_id,
      ).to be_nil
    end

    it "leaves an explicitly unverified email unlinked" do
      userinfo[:email_verified] = false
      authenticate

      expect(session[:current_user_id]).to be_nil
      expect(
        UserAssociatedAccount.find_by(provider_name: "oidc", provider_uid: userinfo[:sub]).user_id,
      ).to be_nil
    end

    it "leaves a missing configured claim unlinked even when the ID token has an email" do
      userinfo.delete(:mail)
      authenticate

      expect(session[:current_user_id]).to be_nil
      expect(
        UserAssociatedAccount.find_by(provider_name: "oidc", provider_uid: userinfo[:sub]).user_id,
      ).to be_nil
    end

    %i[array object boolean number].each do |type|
      it "leaves existing associations unchanged for an email claim of type #{type}" do
        old_association =
          Fabricate(
            :user_associated_account,
            user: user,
            provider_name: "oidc",
            provider_uid: "old-provider-uid",
          )
        userinfo[:mail] = {
          array: [user.email],
          object: {
            email: user.email,
          },
          boolean: true,
          number: 123,
        }.fetch(type)

        authenticate

        expect(response).to have_http_status(:found)
        expect(session[:current_user_id]).to be_nil
        expect(old_association.reload.user_id).to eq(user.id)
        expect(
          UserAssociatedAccount.find_by(
            provider_name: "oidc",
            provider_uid: userinfo[:sub],
          ).user_id,
        ).to be_nil
      end
    end
  end
end
