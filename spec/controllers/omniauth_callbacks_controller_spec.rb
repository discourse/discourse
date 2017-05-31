require 'rails_helper'

describe Users::OmniauthCallbacksController do

  context ".find_authenticator" do
    it "fails if a provider is disabled" do
      SiteSetting.enable_twitter_logins = false

      expect {
        Users::OmniauthCallbacksController.find_authenticator("twitter")
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "fails for unknown" do
      expect {
        Users::OmniauthCallbacksController.find_authenticator("twitter1")
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds an authenticator when enabled" do
      SiteSetting.enable_twitter_logins = true
      expect(Users::OmniauthCallbacksController.find_authenticator("twitter")).not_to eq(nil)
    end
  end

end
