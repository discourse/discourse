# frozen_string_literal: true

require 'rails_helper'

def auth_token_for(user)
  {
    provider: "github",
    extra: {
      all_emails: [{
        email: user.email,
        primary: true,
        verified: true,
      }]
    },
    info: {
      email: user.email,
      nickname: user.username,
      name: user.name,
      image: "https://avatars3.githubusercontent.com/u/#{user.username}",
    },
    uid: '100'
  }
end

describe Auth::GithubAuthenticator do
  let(:authenticator) { described_class.new }
  fab!(:user) { Fabricate(:user) }

  context 'after_authenticate' do
    let(:data) { auth_token_for(user) }

    it 'can authenticate and create a user record for already existing users' do
      result = authenticator.after_authenticate(data)

      expect(result.user.id).to eq(user.id)
      expect(result.username).to eq(user.username)
      expect(result.name).to eq(user.name)
      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)

      # Authenticates again when user has GitHub user info
      result = authenticator.after_authenticate(data)

      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)
    end

    it 'can authenticate and update GitHub screen_name for existing user' do
      UserAssociatedAccount.create!(user_id: user.id, provider_name: "github", provider_uid: 100, info: { nickname: "boris" })

      result = authenticator.after_authenticate(data)

      expect(result.user.id).to eq(user.id)
      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)
      expect(UserAssociatedAccount.find_by(provider_name: "github", user_id: user.id).info["nickname"]).to eq(user.username)
    end

    it 'should use primary email for new user creation over other available emails' do
      hash = {
        provider: "github",
        extra: {
          all_emails: [{
            email: "bob@example.com",
            primary: false,
            verified: true,
          }, {
            email: "john@example.com",
            primary: true,
            verified: true,
          }]
        },
        info: {
          email: "john@example.com",
          nickname: "john",
          name: "John Bob",
        },
        uid: "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.email).to eq("john@example.com")
    end

    it 'should not error out if user already has a different old github account attached' do

      # There is a rare case where an end user had
      # 2 different github accounts and moved emails between the 2

      UserAssociatedAccount.create!(user_id: user.id, info: { nickname: 'bob' }, provider_uid: 100, provider_name: "github")

      hash = {
        provider: "github",
        extra: {
          all_emails: [{
            email: user.email,
            primary: false,
            verified: true,
          }]
        },
        info: {
          email: "john@example.com",
          nickname: "john",
          name: "John Bob",
        },
        uid: "1001"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
      expect(UserAssociatedAccount.where(user_id: user.id).pluck(:provider_uid)).to eq(["1001"])
    end

    it 'will not authenticate for already existing users with an unverified email' do
      hash = {
        provider: "github",
        extra: {
          all_emails: [{
            email: user.email,
            primary: true,
            verified: false,
          }]
        },
        info: {
          email: user.email,
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
        provider: "github",
        extra: {
          all_emails: [{
            email: "person@example.com",
            primary: true,
            verified: true,
          }]
        },
        info: {
          email: "person@example.com",
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
      expect(result.email_valid).to eq(hash[:info][:email].present?)
    end

    it 'will skip blocklisted domains for non existing users' do
      hash = {
        provider: "github",
        extra: {
          all_emails: [{
            email: "not_allowed@blocklist.com",
            primary: true,
            verified: true,
          }, {
            email: "allowed@allowlist.com",
            primary: false,
            verified: true,
          }]
        },
        info: {
          email: "not_allowed@blocklist.com",
          nickname: "person",
          name: "Person Lastname",
        },
        uid: "100"
      }

      SiteSetting.blocked_email_domains = "blocklist.com"
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(hash[:info][:nickname])
      expect(result.name).to eq(hash[:info][:name])
      expect(result.email).to eq("allowed@allowlist.com")
      expect(result.email_valid).to eq(true)
    end

    it 'will find allowlisted domains for non existing users' do
      hash = {
        provider: "github",
        extra: {
          all_emails: [{
            email: "person@example.com",
            primary: true,
            verified: true,
          }, {
            email: "not_allowed@blocklist.com",
            primary: false,
            verified: true,
          }, {
            email: "allowed@allowlist.com",
            primary: false,
            verified: true,
          }]
        },
        info: {
          email: "person@example.com",
          nickname: "person",
          name: "Person Lastname",
        },
        uid: "100"
      }

      SiteSetting.allowed_email_domains = "allowlist.com"
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.username).to eq(hash[:info][:nickname])
      expect(result.name).to eq(hash[:info][:name])
      expect(result.email).to eq("allowed@allowlist.com")
      expect(result.email_valid).to eq(true)
    end

    it 'can connect to a different existing user account' do
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      expect(authenticator.can_connect_existing_user?).to eq(true)

      UserAssociatedAccount.create!(provider_name: "github", user_id: user1.id, provider_uid: 100, info: { nickname: "boris" })

      result = authenticator.after_authenticate(data, existing_account: user2)

      expect(result.user.id).to eq(user2.id)
      expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(false)
      expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(true)
    end

  end

  context 'revoke' do
    fab!(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::GithubAuthenticator.new }

    it 'raises exception if no entry for user' do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

      it 'revokes correctly' do
        UserAssociatedAccount.create!(provider_name: "github", user_id: user.id, provider_uid: 100, info: { nickname: "boris" })
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end

  end

  describe 'avatar retrieval' do
    let(:job_klass) { Jobs::DownloadAvatarFromUrl }

    context 'when user has a custom avatar' do
      fab!(:user_avatar) { Fabricate(:user_avatar, custom_upload: Fabricate(:upload)) }
      fab!(:user_with_custom_avatar) { Fabricate(:user, user_avatar: user_avatar) }

      it 'does not enqueue a download_avatar_from_url job' do
        expect {
          authenticator.after_authenticate(auth_token_for(user_with_custom_avatar))
        }.to_not change(job_klass.jobs, :size)
      end
    end

    context 'when user does not have a custom avatar' do
      it 'enqueues a download_avatar_from_url job' do
        expect {
          authenticator.after_authenticate(auth_token_for(user))
        }.to change(job_klass.jobs, :size).by(1)

        job_args = job_klass.jobs.last['args'].first

        expect(job_args['url']).to eq("https://avatars3.githubusercontent.com/u/#{user.username}")
        expect(job_args['user_id']).to eq(user.id)
        expect(job_args['override_gravatar']).to eq(false)
      end
    end
  end
end
