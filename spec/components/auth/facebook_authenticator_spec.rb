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
          :email => user.email
        },
        "uid" => "100"
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
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
          :email => "bob@bob.com"
        },
        "uid" => "100"
      }

      authenticator = Auth::FacebookAuthenticator.new

      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.extra_data[:name]).to eq("bob bob")
    end
  end

end
