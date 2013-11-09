require 'spec_helper'

# In the ghetto ... getting the spec to run in autospec
#  thing is we need to load up all auth really early pre-fork
#  it means that the require is not going to get a new copy
Auth.send(:remove_const, :OpenIdAuthenticator)
load 'auth/open_id_authenticator.rb'

describe Auth::OpenIdAuthenticator do

  it "can lookup pre-existing user if trusted" do
    auth = Auth::OpenIdAuthenticator.new("test", "id", trusted: true)

    user = Fabricate(:user)
    result = auth.after_authenticate(info: {email: user.email}, extra: {identity_url: 'abc'})
    result.user.should == user
  end
end
