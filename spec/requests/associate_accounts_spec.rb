# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::AssociateAccountsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

    context 'when attempting reconnect' do
      before do
        SiteSetting.enable_google_oauth2_logins = true
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: '12345',
          info: {
            email: 'someemail@test.com',
          },
          extra: {
            raw_info: {
              email_verified: true,
            }
          },
        )

        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should work correctly' do
        sign_in(user)

        # Reconnect flow:
        post "/auth/google_oauth2?reconnect=true"
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(true)

        OmniAuth.config.mock_auth[:google_oauth2].uid = "123456"
        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)

        expect(session[:current_user_id]).to eq(user.id) # Still logged in
        expect(UserAssociatedAccount.count).to eq(0) # Reconnect has not yet happened

        # Request associate info
        uri = URI.parse(response.redirect_url)
        get "#{uri.path}.json"
        data = JSON.parse(response.body)
        expect(data["provider_name"]).to eq("google_oauth2")
        expect(data["account_description"]).to eq("someemail@test.com")

        # Request as different user, should not work
        sign_in(user2)
        get "#{uri.path}.json"
        expect(response.status).to eq(404)

        # Back to first user
        sign_in(user)
        get "#{uri.path}.json"
        data = JSON.parse(response.body)
        expect(data["provider_name"]).to eq("google_oauth2")

        # Make the connection
        post "#{uri.path}.json"
        expect(response.status).to eq(200)
        expect(UserAssociatedAccount.count).to eq(1)

        # Token cannot be reused
        get "#{uri.path}.json"
        expect(response.status).to eq(404)
      end

      it "returns the correct response for non-existant tokens" do
        get "/associate/12345678901234567890123456789012.json"
        expect(response.status).to eq(404)

        get "/associate/shorttoken.json"
        expect(response.status).to eq(404)
      end

    end
end
