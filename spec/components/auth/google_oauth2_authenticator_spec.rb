# frozen_string_literal: true

require 'rails_helper'

describe Auth::GoogleOAuth2Authenticator do

  it 'does not look up user unless email is verified' do
    # note, emails that come back from google via omniauth are always valid
    # this protects against future regressions

    authenticator = Auth::GoogleOAuth2Authenticator.new
    user = Fabricate(:user)

    hash = {
      provider: "google_oauth2",
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
        provider: "google_oauth2",
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

    it 'can connect to a different existing user account' do
      authenticator = Auth::GoogleOAuth2Authenticator.new
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      UserAssociatedAccount.create!(provider_name: "google_oauth2", user_id: user1.id, provider_uid: 100)

      hash = {
        provider: "google_oauth2",
        uid: "100",
        info: {
            name: "John Doe",
            email: user1.email
        },
        extra: {
          raw_info: {
            email: user1.email,
            email_verified: true,
            name: "John Doe"
          }
        }
      }

      result = authenticator.after_authenticate(hash, existing_account: user2)

      expect(result.user.id).to eq(user2.id)
      expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(false)
      expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(true)
    end

    it 'can create a proper result for non existing users' do
      hash = {
        provider: "google_oauth2",
        uid: "123456789",
        info: {
            first_name: "Jane",
            last_name: "Doe",
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
      expect(result.name).to eq("Jane Doe")
    end
  end

  context 'revoke' do
    fab!(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::GoogleOAuth2Authenticator.new }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

      it 'revokes correctly' do
        UserAssociatedAccount.create!(provider_name: "google_oauth2", user_id: user.id, provider_uid: 12345)
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end

  end
end
