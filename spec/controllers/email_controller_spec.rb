require 'spec_helper'

describe EmailController do

  context '.preferences_redirect' do

    it 'requires you to be logged in' do
      lambda { get :preferences_redirect }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let!(:user) { log_in }

      it 'redirects to your user preferences' do
        get :preferences_redirect
        response.should redirect_to("/users/#{user.username}/preferences")
      end
    end

  end

  context '.resubscribe' do

    let(:user) { Fabricate(:user, email_digests: false) }

    context 'with a valid key' do
      before do
        get :resubscribe, key: user.temporary_key
        user.reload
      end

      it 'subscribes the user' do
        user.email_digests.should == true
      end
    end

  end

  context '.unsubscribe' do

    let(:user) { Fabricate(:user) }

    context 'with a valid key' do
      before do
        get :unsubscribe, key: user.temporary_key
        user.reload
      end

      it 'unsubscribes the user' do
        user.email_digests.should == false
      end

      it "sets the appropriate instance variables" do
        assigns(:success).should be_present
      end
    end

    context "with an expired key or invalid key" do
      before do
        get :unsubscribe, key: 'watwatwat'
      end

      it "sets the appropriate instance variables" do
        assigns(:success).should be_blank
      end
    end

    context 'when logged in as a different user' do
      let!(:logged_in_user) { log_in(:coding_horror) }

      before do
        get :unsubscribe, key: user.temporary_key
        user.reload
      end

      it 'does not unsubscribe the user' do
        user.email_digests.should == true
      end

      it 'sets the appropriate instance variables' do
        assigns(:success).should be_blank
        assigns(:different_user).should be_present
      end
    end

    context 'when logged in as the keyed user' do

      before do
        log_in_user(user)
        get :unsubscribe, key: user.temporary_key
        user.reload
      end

      it 'unsubscribes the user' do
        user.email_digests.should == false
      end

      it 'sets the appropriate instance variables' do
        assigns(:success).should be_present
      end
    end

    it "sets not_found when the key didn't match anything" do
      get :unsubscribe, key: 'asdfasdf'
      assigns(:not_found).should == true
    end

  end

end
