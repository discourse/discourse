require 'rails_helper'

RSpec.describe "OmniAuth Callbacks" do
  let(:user) { Fabricate(:user) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  context 'Google Oauth2' do
    before do
      SiteSetting.enable_google_oauth2_logins = true
    end

    describe 'when user has been verified' do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: '123545',
          info: OmniAuth::AuthHash::InfoHash.new(
            email: user.email,
            name: 'Some name'
          ),
          extra: {
            raw_info: OmniAuth::AuthHash.new(
              email_verified: true,
              email: user.email,
              family_name: 'Huh',
              given_name: user.name,
              gender: 'male',
              name: "#{user.name} Huh",
            )
          },
        )

        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should return the right response' do
        get "/auth/google_oauth2/callback.json"

        expect(response).to be_success

        response_body = JSON.parse(response.body)

        expect(response_body["authenticated"]).to eq(true)
        expect(response_body["awaiting_activation"]).to eq(false)
        expect(response_body["awaiting_approval"]).to eq(false)
        expect(response_body["not_allowed_from_ip_address"]).to eq(false)
        expect(response_body["admin_not_allowed_from_ip_address"]).to eq(false)
      end

      context 'when user has not verified his email' do
        before do
          GoogleUserInfo.create!(google_user_id: '12345', user: user)
          user.update!(active: false)

          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: '12345',
            info: OmniAuth::AuthHash::InfoHash.new(
              email: 'someother_email@test.com',
              name: 'Some name'
            ),
            extra: {
              raw_info: OmniAuth::AuthHash.new(
                email_verified: true,
                email: 'someother_email@test.com',
                family_name: 'Huh',
                given_name: user.name,
                gender: 'male',
                name: "#{user.name} Huh",
              )
            },
          )

          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
        end

        it 'should return the right response' do
          get "/auth/google_oauth2/callback.json"

          expect(response).to be_success

          response_body = JSON.parse(response.body)

          expect(user.reload.active).to eq(false)
          expect(response_body["authenticated"]).to eq(false)
          expect(response_body["awaiting_activation"]).to eq(true)
        end
      end
    end
  end
end
