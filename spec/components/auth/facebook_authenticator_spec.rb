require 'rails_helper'

describe Auth::FacebookAuthenticator do
  let(:hash) {
    {
      provider: "facebook",
      extra: {
        raw_info: {
        }
      },
      info: {
        email: "bob@bob.com",
        first_name: "Bob",
        last_name: "Smith"
      },
      uid: "100"
    }
  }

  let(:authenticator) { Auth::FacebookAuthenticator.new }

  context 'after_authenticate' do
    it 'can authenticate and create a user record for already existing users' do
      user = Fabricate(:user)
      result = authenticator.after_authenticate(hash.deep_merge(info: { email: user.email }))
      expect(result.user.id).to eq(user.id)
    end

    it 'can connect to a different existing user account' do
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      UserAssociatedAccount.create!(provider_name: "facebook", user_id: user1.id, provider_uid: 100)

      result = authenticator.after_authenticate(hash, existing_account: user2)

      expect(result.user.id).to eq(user2.id)
      expect(UserAssociatedAccount.exists?(provider_name: "facebook", user_id: user1.id)).to eq(false)
      expect(UserAssociatedAccount.exists?(provider_name: "facebook", user_id: user2.id)).to eq(true)
    end

    it 'can create a proper result for non existing users' do
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
      expect(result.name).to eq("Bob Smith")
    end
  end

  context 'description_for_user' do
    let(:user) { Fabricate(:user) }

    it 'returns empty string if no entry for user' do
      expect(authenticator.description_for_user(user)).to eq("")
    end

    it 'returns correct information' do
      UserAssociatedAccount.create!(provider_name: "facebook", user_id: user.id, provider_uid: 100, info: { email: "someuser@somedomain.tld" })
      expect(authenticator.description_for_user(user)).to eq('someuser@somedomain.tld')
    end
  end

  context 'revoke' do
    let(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::FacebookAuthenticator.new }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

    context "with valid record" do
      before do
        SiteSetting.facebook_app_id = '123'
        SiteSetting.facebook_app_secret = 'abcde'
        UserAssociatedAccount.create!(provider_name: "facebook", user_id: user.id, provider_uid: 100, info: { email: "someuser@somedomain.tld" })
      end

      it 'revokes correctly' do
        expect(authenticator.description_for_user(user)).to eq("someuser@somedomain.tld")
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end
    end
  end

end
