require 'rails_helper'

# In the ghetto ... getting the spec to run in autospec
#  thing is we need to load up all auth really early pre-fork
#  it means that the require is not going to get a new copy
Auth.send(:remove_const, :GithubAuthenticator)
load 'auth/github_authenticator.rb'

def auth_token_for(user)
  {
    extra: {
      all_emails: [{
        email: user.email,
        primary: true,
        verified: true,
      }]
    },
    info: {
      email: user.email,
      email_verified: true,
      nickname: user.username,
      name: user.name,
      image: "https://avatars3.githubusercontent.com/u/#{user.username}",
    },
    uid: '100'
  }
end

describe Auth::GithubAuthenticator do
  let(:authenticator) { described_class.new }
  let(:user) { Fabricate(:user) }

  context 'after_authenticate' do

    it 'can authenticate and create a user record for already existing users' do
      hash = {
        extra: {
          all_emails: [{
            email: user.email,
            primary: true,
            verified: true,
          }]
        },
        info: {
          email: user.email,
          email_verified: true,
          nickname: user.username,
          name: user.name,
        },
        uid: "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
      expect(result.username).to eq(user.username)
      expect(result.name).to eq(user.name)
      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)
    end

    it 'will not authenticate for already existing users with an unverified email' do
      hash = {
        extra: {
          all_emails: [{
            email: user.email,
            primary: true,
            verified: false,
          }]
        },
        info: {
          email: user.email,
          email_verified: false,
          nickname: user.username,
          name: user.name,
        },
        uid: "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(user.username)
      expect(result.name).to eq(user.name)
      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(false)
    end

    it 'can create a proper result for non existing users' do
      hash = {
        extra: {
          all_emails: [{
            email: "person@example.com",
            primary: true,
            verified: true,
          }]
        },
        info: {
          email: "person@example.com",
          email_verified: true,
          nickname: "person",
          name: "Person Lastname",
        },
        uid: "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(hash[:info][:nickname])
      expect(result.name).to eq(hash[:info][:name])
      expect(result.email).to eq(hash[:info][:email])
      expect(result.email_valid).to eq(hash[:info][:email_verified])
    end

    it 'will skip blacklisted domains for non existing users' do
      hash = {
        extra: {
          all_emails: [{
            email: "not_allowed@blacklist.com",
            primary: true,
            verified: true,
          }, {
            email: "allowed@whitelist.com",
            primary: false,
            verified: true,
          }]
        },
        info: {
          email: "not_allowed@blacklist.com",
          email_verified: true,
          nickname: "person",
          name: "Person Lastname",
        },
        uid: "100"
      }

      SiteSetting.email_domains_blacklist = "blacklist.com"
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(hash[:info][:nickname])
      expect(result.name).to eq(hash[:info][:name])
      expect(result.email).to eq("allowed@whitelist.com")
      expect(result.email_valid).to eq(true)
    end

    it 'will find whitelisted domains for non existing users' do
      hash = {
        extra: {
          all_emails: [{
            email: "person@example.com",
            primary: true,
            verified: true,
          }, {
            email: "not_allowed@blacklist.com",
            primary: true,
            verified: true,
          }, {
            email: "allowed@whitelist.com",
            primary: false,
            verified: true,
          }]
        },
        info: {
          email: "person@example.com",
          email_verified: true,
          nickname: "person",
          name: "Person Lastname",
        },
        uid: "100"
      }

      SiteSetting.email_domains_whitelist = "whitelist.com"
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(hash[:info][:nickname])
      expect(result.name).to eq(hash[:info][:name])
      expect(result.email).to eq("allowed@whitelist.com")
      expect(result.email_valid).to eq(true)
    end

  end

  describe 'avatar retrieval' do
    context 'when user has a custom avatar' do
      let(:user_avatar) { Fabricate(:user_avatar, custom_upload: Fabricate(:upload)) }
      let(:user_with_custom_avatar) { Fabricate(:user, user_avatar: user_avatar) }

      it 'does not enqueue a download_avatar_from_url job' do
        Jobs.expects(:enqueue).with(:download_avatar_from_url, anything).never

        result = authenticator.after_authenticate(auth_token_for(user_with_custom_avatar))
      end
    end

    context 'when user does not have a custom avatar' do
      it 'enqueues a download_avatar_from_url job' do
        Jobs.expects(:enqueue).with(
          :download_avatar_from_url,
          url: "https://avatars3.githubusercontent.com/u/#{user.username}",
          user_id: user.id,
          override_gravatar: false
        )

        result = authenticator.after_authenticate(auth_token_for(user))
      end
    end
  end
end
