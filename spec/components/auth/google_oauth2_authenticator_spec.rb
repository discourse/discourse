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

    describe "get_groups" do
      before do
        @profile_scopes = ['email', 'profile']
        @group_scopes = [Auth::GoogleOAuth2Authenticator::GROUPS_SCOPE]
        SiteSetting.google_oauth2_hd_groups = "mydomain.com"
      end

      def group_hash(domain: "mydomain.com", session: group_session)
        {
          provider: "google_oauth2",
          uid: "123456789",
          info: {
            first_name: "Jane",
            last_name: "Doe",
            name: "Jane Doe",
            email: "jane.doe@#{domain}"
          },
          credentials: {
            token: "1245678",
            expires: true,
            expires_at: 1615183562,
            refresh_token: "1/12346678",
          },
          extra: {
            raw_info: {
              email: "jane.doe@#{domain}",
              email_verified: true,
              name: "Jane Doe",
              hd: domain
            }
          },
          session: session
        }
      end

      def group_session(domain: "mydomain.com", scopes: (@profile_scopes + @group_scopes), state: '')
        url = URI::HTTPS.build(
          host: 'discourse.com',
          path: '/auth/google_oauth2/callback',
          query: {
            state: state,
            code: 'abcde',
            scope: scopes.join(' '),
            hd: domain
          }.to_query
        )
        env = Rack::MockRequest.env_for(url.to_s)
        request = Rack::Request.new(env)
        Rack::Session::Abstract::SessionHash.new({}, request)
      end

      it "works if token has group scope" do
        authenticator = described_class.new
        authenticator.stubs(:request_groups).returns({
          "groups" => [
            { "name" => "group1" }
          ]
        })

        result = authenticator.after_authenticate(group_hash)

        expect(result.associated_groups).to eq(['group1'])
        expect(result.extra_data[:provider_domain]).to eq("mydomain.com")
      end

      it "can paginate" do
        authenticator = described_class.new
        authenticator.stubs(:request_groups).returns({
          "groups" => [
            { "name" => "group1" }
          ],
          "nextPageToken" => "123456"
        }).then.returns({
          "groups" => [
            { "name" => "group2" }
          ]
        })
        result = authenticator.after_authenticate(group_hash)

        expect(result.associated_groups).to eq(['group1', 'group2'])
        expect(result.extra_data[:provider_domain]).to eq("mydomain.com")
      end

      it "will request secondary auth if token doesn't have group scope" do
        authenticator = described_class.new

        session = group_session(scopes: @profile_scopes)
        hash = group_hash(session: session)
        result = authenticator.after_authenticate(hash)

        expect(result.secondary_authorization_url).to eq(authenticator.secondary_authorization_url)
      end

      it "wont request secondary auth if handling response to secondary auth" do
        authenticator = described_class.new
        authenticator.stubs(:request_groups).returns({ "groups" => [] })

        session = group_session(state: 'secondary')
        hash = group_hash(session: session)
        result = authenticator.after_authenticate(hash)

        expect(result.secondary_authorization_url).to eq(nil)
      end

      it "does nothing if domain doesn't match" do
        SiteSetting.google_oauth2_hd_groups = "notmydomain.com"
        authenticator = described_class.new
        result = authenticator.after_authenticate(group_hash)

        expect(result.secondary_authorization_url).to eq(nil)
        expect(result.associated_groups).to eq(nil)
        expect(result.extra_data[:provider_domain]).to eq(nil)
      end

      it "does nothing if there are no domains" do
        SiteSetting.google_oauth2_hd_groups = ""
        authenticator = described_class.new
        result = authenticator.after_authenticate(group_hash)

        expect(result.secondary_authorization_url).to eq(nil)
        expect(result.associated_groups).to eq(nil)
        expect(result.extra_data[:provider_domain]).to eq(nil)
      end
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
