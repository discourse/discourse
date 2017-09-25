require 'rails_helper'

describe FinishInstallationController do

  describe '.index' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "doesn't allow access" do
        get :index
        expect(response).not_to be_success
      end
    end

    context "has_login_hint is true" do
      before do
        SiteSetting.has_login_hint = true
      end

      it "allows access" do
        get :index
        expect(response).to be_success
      end
    end
  end

  describe '.register' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "doesn't allow access" do
        get :register
        expect(response).not_to be_success
      end
    end

    context "has_login_hint is true" do
      before do
        SiteSetting.has_login_hint = true
        GlobalSetting.stubs(:developer_emails).returns("robin@example.com")
      end

      it "allows access" do
        get :register
        expect(response).to be_success
      end

      it "raises an error when the email is not in the allowed list" do
        expect do
          post :register, params: {
            email: 'notrobin@example.com',
            username: 'eviltrout',
            password: 'disismypasswordokay'
          }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it "doesn't redirect when fields are wrong" do
        post :register, params: {
          email: 'robin@example.com',
          username: '',
          password: 'disismypasswordokay'
        }

        expect(response).not_to be_redirect
      end

      it "registers the admin when the email is in the list" do
        Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))

        post :register, params: {
          email: 'robin@example.com',
          username: 'eviltrout',
          password: 'disismypasswordokay'
        }, format: :json

        expect(response).to be_redirect
        expect(User.where(username: 'eviltrout').exists?).to eq(true)
      end

    end
  end

  describe '.confirm_email' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "shows the page" do
        get :confirm_email
        expect(response).to be_success
      end
    end
  end

  describe '.resend_email' do
    before do
      SiteSetting.has_login_hint = true
      GlobalSetting.stubs(:developer_emails).returns("robin@example.com")

      post :register, params: {
        email: 'robin@example.com',
        username: 'eviltrout',
        password: 'disismypasswordokay'
      }
    end

    it "resends the email" do
      Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))
      get :resend_email
      expect(response).to be_success
    end
  end
end
