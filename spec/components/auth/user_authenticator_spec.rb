require 'rails_helper'

RSpec.describe UserAuthenticator do
  let(:user) { Fabricate(:user, email: 'test@discourse.org') }

  describe "#finish" do
    before do
      SiteSetting.enable_google_oauth2_logins = true
    end

    it "should execute provider's callback" do
      user.update!(email: 'test@gmail.com')

      authenticator = UserAuthenticator.new(user, { authentication: {
        authenticator_name: Auth::GoogleOAuth2Authenticator.new.name,
        email: user.email,
        email_valid: true,
        extra_data: { google_user_id: 1 }
      }})

      expect { authenticator.finish }.to change { GoogleUserInfo.count }.by(1)
    end

    describe "when session's email is different from user's email" do
      it "should not execute provider's callback" do
        authenticator = UserAuthenticator.new(user, { authentication: {
          authenticator_name: Auth::GoogleOAuth2Authenticator.new.name,
          email: 'test@gmail.com',
          email_valid: true
        }})

        expect { authenticator.finish }.to_not change { GoogleUserInfo.count }
      end
    end
  end
end
