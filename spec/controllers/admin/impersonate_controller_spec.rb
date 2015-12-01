require 'rails_helper'

describe Admin::ImpersonateController do

  it "is a subclass of AdminController" do
    expect(Admin::ImpersonateController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    let!(:admin) { log_in(:admin) }
    let(:user) { Fabricate(:user) }

    context 'index' do
      it 'returns success' do
        xhr :get, :index
        expect(response).to be_success
      end
    end

    context 'create' do

      it 'requires a username_or_email parameter' do
        expect { xhr :put, :create }.to raise_error(ActionController::ParameterMissing)
      end

      it 'returns 404 when that user does not exist' do
        xhr :post, :create, username_or_email: 'hedonismbot'
        expect(response.status).to eq(404)
      end

      it "raises an invalid access error if the user can't be impersonated" do
        Guardian.any_instance.expects(:can_impersonate?).with(user).returns(false)
        xhr :post, :create, username_or_email: user.email
        expect(response).to be_forbidden
      end

      context 'success' do

        it "logs the impersonation" do
          StaffActionLogger.any_instance.expects(:log_impersonate)
          xhr :post, :create, username_or_email: user.username
        end

        it "changes the current user session id" do
          xhr :post, :create, username_or_email: user.username
          expect(session[:current_user_id]).to eq(user.id)
        end

        it "returns success" do
          xhr :post, :create, username_or_email: user.email
          expect(response).to be_success
        end

        it "also works with an email address" do
          xhr :post, :create, username_or_email: user.email
          expect(session[:current_user_id]).to eq(user.id)
        end

      end

    end

  end

end
