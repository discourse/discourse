require 'rails_helper'

# In the ghetto ... getting the spec to run in autospec
#  thing is we need to load up all auth really early pre-fork
#  it means that the require is not going to get a new copy
Auth.send(:remove_const, :OpenIdAuthenticator)
load 'auth/open_id_authenticator.rb'

describe Auth::OpenIdAuthenticator do

  it "can lookup pre-existing user if trusted" do
    auth = Auth::OpenIdAuthenticator.new("test", "id", trusted: true)

    user = Fabricate(:user)
    response = OpenStruct.new(identity_url: 'abc')
    result = auth.after_authenticate(info: { email: user.email }, extra: { response: response })
    expect(result.user).to eq(user)
  end

  it "raises an exception when email is missing" do
    auth = Auth::OpenIdAuthenticator.new("test", "id", trusted: true)
    response = OpenStruct.new(identity_url: 'abc')
    expect { auth.after_authenticate(info: {}, extra: { response: response }) }.to raise_error(Discourse::InvalidParameters)
  end
end
