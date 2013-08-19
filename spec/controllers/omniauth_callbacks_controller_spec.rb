require 'spec_helper'

describe Users::OmniauthCallbacksController do

  let(:auth) { {info: {email: 'eviltrout@made.up.email', name: 'Robin Ward', uid: 123456789}, "extra" => {"raw_info" => {} } } }
  let(:cas_auth) { { 'uid' => 'casuser', extra: { user: 'casuser'}  }  }

  shared_examples_for "an authenticaton provider" do |provider|
    context "when #{provider} logins are disabled" do
      before do
        SiteSetting.stubs("enable_#{provider}_logins?").returns(false)
      end

      it "fails" do
        get :complete, provider: provider
        response.should_not be_success
      end

    end

    context "when #{provider} logins are enabled" do
      before do
        SiteSetting.stubs("enable_#{provider}_logins?").returns(true)
      end

      it "succeeds" do
        get :complete, provider: provider
        response.should be_success
      end

      context "and 'invite only' site setting is enabled" do
        before do
          SiteSetting.stubs(:invite_only?).returns(true)
        end

        it "informs the user they are awaiting approval" do
          xhr :get, :complete, provider: provider, format: :json

          expect(
            JSON.parse(response.body)['awaiting_approval']
          ).to be_true
        end
      end

    end

  end

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

    it_behaves_like "an authenticaton provider", 'twitter'

  end

  describe 'facebook' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it_behaves_like "an authenticaton provider", 'facebook'

  end

  describe 'cas' do

    before do
      request.env["omniauth.auth"] = cas_auth
    end

    it_behaves_like "an authenticaton provider", 'cas'

    describe "extracted user data" do
      before do
        SiteSetting.stubs(:enable_cas_logins?).returns(true)
      end

      subject {
        xhr :get, :complete, provider: 'cas', format: :json
        OpenStruct.new(JSON.parse(response.body))
      }

      context "when no user infos are returned by cas" do
        its(:username) { should eq 'casuser' }
        its(:name) { should eq 'casuser' }
        its(:email) { should eq 'casuser' } # No cas_domainname configured!

        context "when cas_domainname is configured" do
          before do
            SiteSetting.stubs(:cas_domainname).returns("example.com")
          end

          its(:email) { should eq 'casuser@example.com' }
        end
      end

      context "when user infos are returned by cas" do
        before do
          request.env["omniauth.auth"] = cas_auth.merge({
            info: {
              name: 'Proper Name',
              email: 'public@example.com'
              }
          })
        end

        its(:username) { should eq 'casuser' }
        its(:name) { should eq 'Proper Name' }
        its(:email) { should eq 'public@example.com' }
      end

    end

  end


  describe 'open id handler' do

    before do
      request.env["omniauth.auth"] = { info: {email: 'eviltrout@made.up.email'}, extra: {identity_url: 'http://eviltrout.com'}}
    end

    describe "google" do
      it_behaves_like "an authenticaton provider", 'google'
    end

    describe "yahoo" do
      it_behaves_like "an authenticaton provider", 'yahoo'
    end

  end

  describe 'github' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it_behaves_like "an authenticaton provider", 'github'

  end

  describe 'persona' do

    before do
      request.env["omniauth.auth"] = auth
    end

    it_behaves_like "an authenticaton provider", 'persona'

  end

  describe 'oauth2' do
    before do
      Discourse.stubs(:auth_providers).returns([stub(name: 'my_oauth2_provider', type: :oauth2)])
      request.env["omniauth.auth"] = { uid: 'my-uid', provider: 'my-oauth-provider-domain.net', info: {email: 'eviltrout@made.up.email', name: 'Chatanooga'}}
    end

    describe "#create_or_sign_on_user_using_oauth2" do
      context "User already exists" do
        before do
          User.stubs(:find_by_email).returns(Fabricate(:user))
        end

        it "should create an OauthUserInfo" do
          expect {
            post :complete, provider: 'my_oauth2_provider'
          }.to change { Oauth2UserInfo.count }.by(1)
        end
      end
    end
  end

end
