require 'rails_helper'

describe UsersEmailController do

  describe '.confirm' do
    it 'errors out for invalid tokens' do
      get :confirm, token: 'asdfasdf'
      expect(response).to be_success
      expect(assigns(:update_result)).to eq(:error)
    end

    context 'valid old address token' do
      let(:user) { Fabricate(:moderator) }
      let(:updater) { EmailUpdater.new(user.guardian, user) }

      before do
        updater.change_to('new.n.cool@example.com')
      end

      it 'confirms with a correct token' do
        get :confirm, token: user.email_tokens.last.token
        expect(response).to be_success
        expect(assigns(:update_result)).to eq(:authorizing_new)
      end
    end

    context 'valid new address token' do
      let(:user) { Fabricate(:user) }
      let(:updater) { EmailUpdater.new(user.guardian, user) }

      before do
        updater.change_to('new.n.cool@example.com')
      end

      it 'confirms with a correct token' do
        get :confirm, token: user.email_tokens.last.token
        expect(response).to be_success
        expect(assigns(:update_result)).to eq(:complete)
      end
    end
  end

  describe '.update' do
    let(:new_email) { 'bubblegum@adventuretime.ooo' }

    it "requires you to be logged in" do
      expect { xhr :put, :update, username: 'asdf', email: new_email }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let!(:user) { log_in }

      it 'raises an error without an email parameter' do
        expect { xhr :put, :update, username: user.username }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error if you can't edit the user's email" do
        Guardian.any_instance.expects(:can_edit_email?).with(user).returns(false)
        xhr :put, :update, username: user.username, email: new_email
        expect(response).to be_forbidden
      end

      context 'when the new email address is taken' do
        let!(:other_user) { Fabricate(:coding_horror) }
        it 'raises an error' do
          xhr :put, :update, username: user.username, email: other_user.email
          expect(response).to_not be_success
        end

        it 'raises an error if there is whitespace too' do
          xhr :put, :update, username: user.username, email: other_user.email + ' '
          expect(response).to_not be_success
        end
      end

      context 'when new email is different case of existing email' do
        let!(:other_user) { Fabricate(:user, email: 'case.insensitive@gmail.com')}

        it 'raises an error' do
          xhr :put, :update, username: user.username, email: other_user.email.upcase
          expect(response).to_not be_success
        end
      end

      it 'raises an error when new email domain is present in email_domains_blacklist site setting' do
        SiteSetting.email_domains_blacklist = "mailinator.com"
        xhr :put, :update, username: user.username, email: "not_good@mailinator.com"
        expect(response).to_not be_success
      end

      it 'raises an error when new email domain is not present in email_domains_whitelist site setting' do
        SiteSetting.email_domains_whitelist = "discourse.org"
        xhr :put, :update, username: user.username, email: new_email
        expect(response).to_not be_success
      end

      context 'success' do
        it 'has an email token' do
          expect { xhr :put, :update, username: user.username, email: new_email }.to change(EmailChangeRequest, :count)
        end
      end
    end

  end

end
