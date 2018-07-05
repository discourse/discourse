require 'rails_helper'

# In the ghetto ... getting the spec to run in autospec
#  thing is we need to load up all auth really early pre-fork
#  it means that the require is not going to get a new copy
Auth.send(:remove_const, :FacebookAuthenticator)
load 'auth/facebook_authenticator.rb'

describe Auth::FacebookAuthenticator do

  context 'after_authenticate' do
    it 'can authenticate and create a user record for already existing users' do
      authenticator = Auth::FacebookAuthenticator.new
      user = Fabricate(:user)

      hash = {
        "extra" => {
            "raw_info" => {
            "username" => "bob"
          }
        },
        "info" => {
          :email => user.email,
          "location" => "America",
          "description" => "bio",
          "urls" => {
            "Website" => "https://awesome.com"
          }
        },
        "uid" => "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
      expect(result.user.user_profile.website).to eq("https://awesome.com")
      expect(result.user.user_profile.bio_raw).to eq("bio")
      expect(result.user.user_profile.location).to eq("America")
    end

    it 'can connect to a different existing user account' do
      authenticator = Auth::FacebookAuthenticator.new
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      FacebookUserInfo.create!(user_id: user1.id, facebook_user_id: 100)

      hash = {
        "extra" => {
            "raw_info" => {
            "username" => "bob"
          }
        },
        "info" => {
          "location" => "America",
          "description" => "bio",
          "urls" => {
            "Website" => "https://awesome.com"
          }
        },
        "uid" => "100"
      }

      result = authenticator.after_authenticate(hash, existing_account: user2)

      expect(result.user.id).to eq(user2.id)
      expect(FacebookUserInfo.find_by(user_id: user1.id)).to be(nil)
      expect(FacebookUserInfo.find_by(user_id: user2.id)).not_to be(nil)
    end

    it 'can create a proper result for non existing users' do

      hash = {
        "extra" => {
            "raw_info" => {
            "username" => "bob",
            "name" => "bob bob"
          }
        },
        "info" => {
          email: "bob@bob.com"
        },
        "uid" => "100"
      }

      authenticator = Auth::FacebookAuthenticator.new

      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.extra_data[:name]).to eq("bob bob")
    end
  end

  context 'description_for_user' do
    let(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::FacebookAuthenticator.new }

    it 'returns nil if no entry for user' do
      expect(authenticator.description_for_user(user)).to eq(nil)
    end

    it 'returns correct information' do
      FacebookUserInfo.create!(user_id: user.id, facebook_user_id: 12345, email: 'someuser@somedomain.tld')
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
        FacebookUserInfo.create!(user_id: user.id, facebook_user_id: 12345, email: 'someuser@somedomain.tld')
      end

      it 'revokes correctly' do
        stub = stub_request(:delete, 'https://graph.facebook.com/12345/permissions?access_token=123%7Cabcde').to_return(body: "true")

        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)

        expect(stub).to have_been_requested.once
        expect(authenticator.description_for_user(user)).to eq(nil)
      end

      it 'handles errors correctly' do
        stub = stub_request(:delete, 'https://graph.facebook.com/12345/permissions?access_token=123%7Cabcde').to_return(status: 404)

        expect(authenticator.revoke(user)).to eq(false)
        expect(stub).to have_been_requested.once
        expect(authenticator.description_for_user(user)).to eq('someuser@somedomain.tld')

        expect(authenticator.revoke(user, skip_remote: true)).to eq(true)
        expect(stub).to have_been_requested.once
        expect(authenticator.description_for_user(user)).to eq(nil)

      end
    end
  end

end
