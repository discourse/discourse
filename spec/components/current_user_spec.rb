require 'spec_helper'
require_dependency 'current_user'

describe CurrentUser do
  it "allows us to lookup a user from our environment" do
    user = Fabricate(:user, auth_token: EmailToken.generate_token)
    CurrentUser.lookup_from_env("HTTP_COOKIE" => "_t=#{user.auth_token};").should == user
  end

  # it "allows us to lookup a user from our app" do
  # end

end
