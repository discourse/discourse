require 'spec_helper'

describe Users::OmniauthCallbacksController do

  let(:auth) { {info: {email: 'eviltrout@made.up.email', name: 'Robin Ward', uid: 123456789}, "extra" => {"raw_info" => {} } } }
  let(:cas_auth) {{ uid: "caluser2", extra: {user: "caluser2"}  }  }
  describe 'invalid provider' do

    it "fails" do
      request.env["omniauth.auth"] = auth
      get :complete, provider: 'hackprovider'
      response.should_not be_success
    end

  end

  describe 'twitter' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it "fails when twitter logins are disabled" do
      SiteSetting.stubs(:enable_twitter_logins?).returns(false)
      get :complete, provider: 'twitter'
      response.should_not be_success
    end

    it "succeeds when twitter logins are enabled" do
      SiteSetting.stubs(:enable_twitter_logins?).returns(true)
      get :complete, provider: 'twitter'
      response.should be_success
    end

    context "when 'invite only' site setting is enabled" do
      before { SiteSetting.stubs(:invite_only?).returns(true) }

      it 'informs the user they are awaiting approval' do
        xhr :get, :complete, provider: 'twitter', format: :json

        expect(
          JSON.parse(response.body)['awaiting_approval']
        ).to be_true
      end
    end
  end

  describe 'facebook' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it "fails when facebook logins are disabled" do
      SiteSetting.stubs(:enable_facebook_logins?).returns(false)
      get :complete, provider: 'facebook'
      response.should_not be_success
    end

    it "succeeds when facebook logins are enabled" do
      SiteSetting.stubs(:enable_facebook_logins?).returns(true)
      get :complete, provider: 'facebook'
      response.should be_success
    end

  end

  describe 'cas' do

    before do
      request.env["omniauth.auth"] = cas_auth
    end

    it "fails when cas logins are disabled" do
      SiteSetting.stubs(:enable_cas_logins?).returns(false)
      get :complete, provider: 'cas'
      response.should_not be_success
    end

    it "succeeds when cas logins are enabled" do
      SiteSetting.stubs(:enable_cas_logins?).returns(true)
      get :complete, provider: 'cas'
      response.should be_success
    end

  end


  describe 'open id handler' do

    before do
      request.env["omniauth.auth"] = { info: {email: 'eviltrout@made.up.email'}, extra: {identity_url: 'http://eviltrout.com'}}
    end

    describe "google" do
      it "fails when google logins are disabled" do
        SiteSetting.stubs(:enable_google_logins?).returns(false)
        get :complete, provider: 'google'
        response.should_not be_success
      end

      it "succeeds when google logins are enabled" do
        SiteSetting.stubs(:enable_google_logins?).returns(true)
        get :complete, provider: 'google'
        response.should be_success
      end
    end

    describe "yahoo" do
      it "fails when yahoo logins are disabled" do
        SiteSetting.stubs(:enable_yahoo_logins?).returns(false)
        get :complete, provider: 'yahoo'
        response.should_not be_success
      end

      it "succeeds when yahoo logins are enabled" do
        SiteSetting.stubs(:enable_yahoo_logins?).returns(true)
        get :complete, provider: 'yahoo'
        response.should be_success
      end
    end

  end

  describe 'github' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it "fails when github logins are disabled" do
      SiteSetting.stubs(:enable_github_logins?).returns(false)
      get :complete, provider: 'github'
      response.should_not be_success
    end

    it "succeeds when github logins are enabled" do
      SiteSetting.stubs(:enable_github_logins?).returns(true)
      get :complete, provider: 'github'
      response.should be_success
    end

  end

  describe 'persona' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it "fails when persona logins are disabled" do
      SiteSetting.stubs(:enable_persona_logins?).returns(false)
      get :complete, provider: 'persona'
      response.should_not be_success
    end

    it "succeeds when persona logins are enabled" do
      SiteSetting.stubs(:enable_persona_logins?).returns(true)
      get :complete, provider: 'persona'
      response.should be_success
    end

  end

end
