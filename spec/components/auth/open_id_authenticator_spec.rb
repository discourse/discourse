require 'rails_helper'

describe Auth::OpenIdAuthenticator do

  it "can lookup pre-existing user if trusted" do
    auth = Auth::OpenIdAuthenticator.new("test", "id", "enable_yahoo_logins", trusted: true)

    user = Fabricate(:user)
    response = OpenStruct.new(identity_url: 'abc')
    result = auth.after_authenticate(info: { email: user.email }, extra: { response: response })
    expect(result.user).to eq(user)
  end

  it "raises an exception when email is missing" do
    auth = Auth::OpenIdAuthenticator.new("test", "id", "enable_yahoo_logins", trusted: true)
    response = OpenStruct.new(identity_url: 'abc')
    expect { auth.after_authenticate(info: {}, extra: { response: response }) }.to raise_error(Discourse::InvalidParameters)
  end

  it 'can connect to a different existing user account' do
    authenticator = Auth::OpenIdAuthenticator.new("test", "id", "enable_yahoo_logins", trusted: true)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    UserOpenId.create!(url: "id/123" , user_id: user1.id, email: "bob@example.com", active: true)

    hash = {
      info: { email: user1.email }, extra: { response: OpenStruct.new(identity_url: 'id/123') }
    }

    result = authenticator.after_authenticate(hash, existing_account: user2)

    expect(result.user.id).to eq(user2.id)
    expect(UserOpenId.exists?(user_id: user1.id)).to eq(false)
    expect(UserOpenId.exists?(user_id: user2.id)).to eq(true)
  end

  context 'revoke' do
    let(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::OpenIdAuthenticator.new("test", "id", "enable_yahoo_logins", trusted: true) }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

      it 'revokes correctly' do
        UserOpenId.create!(url: "id/123" , user_id: user.id, email: "bob@example.com", active: true)
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end

  end
end
