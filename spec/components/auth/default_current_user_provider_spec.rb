require 'spec_helper'
require_dependency 'auth/default_current_user_provider'

describe Auth::DefaultCurrentUserProvider do

  def provider(url, opts=nil)
    opts ||= {method: "GET"}
    env = Rack::MockRequest.env_for(url, opts)
    Auth::DefaultCurrentUserProvider.new(env)
  end

  it "raises errors for incorrect api_key" do
    expect{
      provider("/?api_key=INCORRECT").current_user
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "finds a user for a correct per-user api key" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)
    provider("/?api_key=hello").current_user.id.should == user.id
  end

  it "raises for a user pretending" do
    user = Fabricate(:user)
    user2 = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)

    expect{
      provider("/?api_key=hello&api_username=#{user2.username.downcase}").current_user
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "finds a user for a correct system api key" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", created_by_id: -1)
    provider("/?api_key=hello&api_username=#{user.username.downcase}").current_user.id.should == user.id
  end

  it "should not update last seen for message bus" do
    provider("/message-bus/anything/goes", method: "POST").should_update_last_seen?.should == false
    provider("/message-bus/anything/goes", method: "GET").should_update_last_seen?.should == false
  end

  it "should update last seen for others" do
    provider("/topic/anything/goes", method: "POST").should_update_last_seen?.should == true
    provider("/topic/anything/goes", method: "GET").should_update_last_seen?.should == true
  end
end

