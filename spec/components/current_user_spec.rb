require 'spec_helper'
require_dependency 'current_user'

describe CurrentUser do
  let(:user) { Fabricate(:user, auth_token: EmailToken.generate_token) }
  let(:env) { {"HTTP_COOKIE" => "_t=#{user.auth_token};"} }

  it "allows us to lookup a user from our environment" do
    CurrentUser.lookup_from_env(env).should == user
  end

  describe "#clear_current_user" do
    subject { ApplicationController.new }

    before :each do
      subject.stubs(:request).returns(stub(env: env))
    end

    it "allows a new provider from request.env after clearing" do
      subject.clear_current_user
      subject.current_user.should == user
    end
  end
end
