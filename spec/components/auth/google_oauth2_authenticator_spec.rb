require 'rails_helper'

# For autospec:
Auth.send(:remove_const, :GoogleOAuth2Authenticator)
load 'auth/google_oauth2_authenticator.rb'

describe Auth::GoogleOAuth2Authenticator do

  it 'does not look up user unless email is verified' do
    # note, emails that come back from google via omniauth are always valid
    # this protects against future regressions

    authenticator = Auth::GoogleOAuth2Authenticator.new
    user = Fabricate(:user)

    hash = {
      uid: "123456789",
      info: {
          name: "John Doe",
          email: user.email
      },
      extra: {
        raw_info: {
          email: user.email,
          email_verified: false,
          name: "John Doe"
        }
      }
    }

    result = authenticator.after_authenticate(hash)

    expect(result.user).to eq(nil)
  end

  context 'after_authenticate' do
    it 'can authenticate and create a user record for already existing users' do
      authenticator = Auth::GoogleOAuth2Authenticator.new
      user = Fabricate(:user)

      hash = {
        uid: "123456789",
        info: {
            name: "John Doe",
            email: user.email
        },
        extra: {
          raw_info: {
            email: user.email,
            email_verified: true,
            name: "John Doe"
          }
        }
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
    end

    it 'can create a proper result for non existing users' do
      hash = {
        uid: "123456789",
        info: {
            name: "Jane Doe",
            email: "jane.doe@the.google.com"
        },
        extra: {
          raw_info: {
            email: "jane.doe@the.google.com",
            email_verified: true,
            name: "Jane Doe"
          }
        }
      }

      authenticator = described_class.new
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.extra_data[:name]).to eq("Jane Doe")
    end
  end
end
