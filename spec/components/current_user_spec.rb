require 'spec_helper'
require_dependency 'current_user'

describe CurrentUser do
  it "allows us to lookup a user from our environment" do
    token = EmailToken.generate_token
    user = Fabricate.build(:user)
    User.expects(:where).returns([user])
    CurrentUser.lookup_from_env("HTTP_COOKIE" => "_t=#{token};").should == user
  end

  # it "allows us to lookup a user from our app" do
  # end

end
