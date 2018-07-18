require 'rails_helper'

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
    let(:data) do
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
          nickname: user.username,
          name: user.name,
        },
        uid: "100"
      }
    end

    it 'can authenticate and create a user record for already existing users' do
      result = authenticator.after_authenticate(data)

      expect(result.user.id).to eq(user.id)
      expect(result.username).to eq(user.username)
      expect(result.name).to eq(user.name)
      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)

      # Authenticates again when user has Github user info
      result = authenticator.after_authenticate(data)

      expect(result.email).to eq(user.email)
      expect(result.email_valid).to eq(true)
    end

    it 'should use primary email for new user creation over other available emails' do
      hash = {
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
            primary: false,
            verified: true,
          }, {
            email: "allowed@whitelist.com",
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
    let(:job_klass) { Jobs::DownloadAvatarFromUrl }

    context 'when user has a custom avatar' do
      let(:user_avatar) { Fabricate(:user_avatar, custom_upload: Fabricate(:upload)) }
      let(:user_with_custom_avatar) { Fabricate(:user, user_avatar: user_avatar) }

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
