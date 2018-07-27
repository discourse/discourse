require 'rails_helper'

describe Auth::TwitterAuthenticator do

  it "takes over account if email is supplied" do
    auth = Auth::TwitterAuthenticator.new

    user = Fabricate(:user)

    auth_token = {
      info: {
        "email" => user.email,
        "username" => "test",
        "name" => "test",
        "nickname" => "minion",
      },
      "uid" => "123"
    }

    result = auth.after_authenticate(auth_token)

    expect(result.user.id).to eq(user.id)

    info = TwitterUserInfo.find_by(user_id: user.id)
    expect(info.email).to eq(user.email)
  end

  it 'can connect to a different existing user account' do
    authenticator = Auth::TwitterAuthenticator.new
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    TwitterUserInfo.create!(user_id: user1.id, twitter_user_id: 100, screen_name: "boris")

    hash = {
      info: {
        "email" => user1.email,
        "username" => "test",
        "name" => "test",
        "nickname" => "minion",
      },
      "uid" => "100"
    }

    result = authenticator.after_authenticate(hash, existing_account: user2)

    expect(result.user.id).to eq(user2.id)
    expect(TwitterUserInfo.exists?(user_id: user1.id)).to eq(false)
    expect(TwitterUserInfo.exists?(user_id: user2.id)).to eq(true)
  end

  context 'revoke' do
    let(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::TwitterAuthenticator.new }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

      it 'revokes correctly' do
        TwitterUserInfo.create!(user_id: user.id, twitter_user_id: 100, screen_name: "boris")
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end

  end

end
