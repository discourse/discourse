require 'spec_helper'

# In the ghetto ... getting the spec to run in autospec
#  thing is we need to load up all auth really early pre-fork
#  it means that the require is not going to get a new copy
Auth.send(:remove_const, :CurrentUserProvider)
load 'auth/current_user_provider.rb'

describe Auth::CurrentUserProvider do
  it "should memoize current_user" do
    env = Rack::MockRequest.env_for("http://example.com/")
    provider = Auth::CurrentUserProvider.new(env)
    provider.expects(:current_user)
    2.times { provider.current_user_wrapper }
  end

  it "should not allow suspended users to be logged in" do
    env = Rack::MockRequest.env_for("http://example.com/")
    user = Fabricate(:user, auth_token: EmailToken.generate_token)
    user.suspended_till = Time.now + 5.minutes
    provider = Auth::CurrentUserProvider.new(env)
    provider.stubs(:current_user).returns(user)
    provider.current_user_wrapper.should == nil
  end

  it "should update last seen and IP address" do
    env = Rack::MockRequest.env_for("http://example.com/")
    user = Fabricate(:user, auth_token: EmailToken.generate_token)
    user.expects(:update_last_seen!)
    user.expects(:update_ip_address!)
    provider = Auth::CurrentUserProvider.new(env)
    provider.stubs(:current_user).returns(user)
    provider.current_user_wrapper
  end

  it "should detect API requests" do
    api_key = ApiKey.create_master_key
    env = Rack::MockRequest.env_for("http://example.com/", params: {api_key: api_key.key})
    provider = Auth::CurrentUserProvider.new(env)
    provider.stubs(:current_user).returns(nil)
    provider.is_api?.should == true
  end
end
