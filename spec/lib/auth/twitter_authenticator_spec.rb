# frozen_string_literal: true

RSpec.describe Auth::TwitterAuthenticator do
  it "takes over account if email is supplied" do
    auth = Auth::TwitterAuthenticator.new

    user = Fabricate(:user)

    auth_token = {
      info: {
        email: user.email,
        username: "test",
        name: "test",
        nickname: "minion",
      },
      uid: "123",
      provider: "twitter",
    }

    result = auth.after_authenticate(auth_token)

    expect(result.user.id).to eq(user.id)

    info = UserAssociatedAccount.find_by(provider_name: "twitter", user_id: user.id)
    expect(info.info["email"]).to eq(user.email)
  end

  it "can connect to a different existing user account" do
    authenticator = Auth::TwitterAuthenticator.new
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    UserAssociatedAccount.create!(provider_name: "twitter", user_id: user1.id, provider_uid: 100)

    hash = {
      info: {
        email: user1.email,
        username: "test",
        name: "test",
        nickname: "minion",
      },
      uid: "100",
      provider: "twitter",
    }

    result = authenticator.after_authenticate(hash, existing_account: user2)

    expect(result.user.id).to eq(user2.id)
    expect(UserAssociatedAccount.exists?(provider_name: "twitter", user_id: user1.id)).to eq(false)
    expect(UserAssociatedAccount.exists?(provider_name: "twitter", user_id: user2.id)).to eq(true)
  end

  describe "revoke" do
    fab!(:user)
    let(:authenticator) { Auth::TwitterAuthenticator.new }

    it "raises exception if no entry for user" do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

    it "revokes correctly" do
      UserAssociatedAccount.create!(provider_name: "twitter", user_id: user.id, provider_uid: 100)
      expect(authenticator.can_revoke?).to eq(true)
      expect(authenticator.revoke(user)).to eq(true)
      expect(authenticator.description_for_user(user)).to eq("")
    end
  end

  describe "#healthy?" do
    let(:authenticator) { described_class.new }
    let(:request_token_url) { "https://api.twitter.com/oauth/request_token" }

    before do
      SiteSetting.twitter_consumer_key = "key"
      SiteSetting.twitter_consumer_secret = "secret"
    end

    it "returns false when either consumer key or secret is blank" do
      SiteSetting.twitter_consumer_key = ""
      expect(authenticator.healthy?).to eq(false)

      SiteSetting.twitter_consumer_key = "key"
      SiteSetting.twitter_consumer_secret = ""
      expect(authenticator.healthy?).to eq(false)
    end

    it "returns true when request to retrieve request token is successful" do
      stub_request(:post, request_token_url).to_return(
        status: 200,
        body: "oauth_token=foo&oauth_token_secret=bar",
      )

      expect(authenticator.healthy?).to eq(true)
    end

    it "returns false when request to retrieve request token returns 401" do
      stub_request(:post, request_token_url).to_return(status: 401)

      expect(authenticator.healthy?).to eq(false)
    end

    it "returns false when request to retrieve request token returns 403" do
      stub_request(:post, request_token_url).to_return(status: 403)

      expect(authenticator.healthy?).to eq(false)
    end

    it "returns false when request to retrieve request token returns 500" do
      stub_request(:post, request_token_url).to_return(status: 500)

      expect(authenticator.healthy?).to eq(false)
    end
  end
end
