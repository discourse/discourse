require 'rails_helper'

describe EmailController do

  context '.preferences_redirect' do

    it 'requires you to be logged in' do
      expect { get :preferences_redirect }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let!(:user) { log_in }

      it 'redirects to your user preferences' do
        get :preferences_redirect
        expect(response).to redirect_to("/users/#{user.username}/preferences")
      end
    end

  end

  context '.resubscribe' do

    let(:user) {
      user = Fabricate(:user)
      user.user_option.update_columns(email_digests: false)
      user
    }
    let(:key) { DigestUnsubscribeKey.create_key_for(user) }

    context 'with a valid key' do
      before do
        get :resubscribe, key: key
        user.reload
      end

      it 'subscribes the user' do
        expect(user.user_option.email_digests).to eq(true)
      end
    end

  end

  context '.unsubscribe' do

    let(:user) {
      user = Fabricate(:user)
      user.user_option.update_columns(email_always: true, email_digests: true, email_direct: true, email_private_messages: true)
      user
    }
    let(:key) { DigestUnsubscribeKey.create_key_for(user) }

    context 'from confirm unsubscribe email' do
      before do
        get :unsubscribe, key: key, from_all: true
        user.reload
      end

      it 'unsubscribes from all emails' do
        options = user.user_option
        expect(options.email_digests).to eq false
        expect(options.email_direct).to eq false
        expect(options.email_private_messages).to eq false
        expect(options.email_always).to eq false
      end
    end

    context 'with a valid key' do
      before do
        get :unsubscribe, key: key
        user.reload
      end

      it 'unsubscribes the user' do
        expect(user.user_option.email_digests).to eq(false)
      end

      it "sets the appropriate instance variables" do
        expect(assigns(:success)).to be_present
      end
    end

    context "with an expired key or invalid key" do
      before do
        get :unsubscribe, key: 'watwatwat'
      end

      it "sets the appropriate instance variables" do
        expect(assigns(:success)).to be_blank
      end
    end

    context 'when logged in as a different user' do
      let!(:logged_in_user) { log_in(:coding_horror) }

      before do
        get :unsubscribe, key: key
        user.reload
      end

      it 'does not unsubscribe the user' do
        expect(user.user_option.email_digests).to eq(true)
      end

      it 'sets the appropriate instance variables' do
        expect(assigns(:success)).to be_blank
        expect(assigns(:different_user)).to be_present
      end
    end

    context 'when logged in as the keyed user' do

      before do
        log_in_user(user)
        get :unsubscribe, key: DigestUnsubscribeKey.create_key_for(user)
        user.reload
      end

      it 'unsubscribes the user' do
        expect(user.user_option.email_digests).to eq(false)
      end

      it 'sets the appropriate instance variables' do
        expect(assigns(:success)).to be_present
      end
    end

    it "sets not_found when the key didn't match anything" do
      get :unsubscribe, key: 'asdfasdf'
      expect(assigns(:not_found)).to eq(true)
    end

  end

end
