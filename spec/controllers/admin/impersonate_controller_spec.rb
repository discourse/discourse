require 'spec_helper'

describe Admin::ImpersonateController do

  it "is a subclass of AdminController" do
    (Admin::ImpersonateController < Admin::AdminController).should be_true
  end


  context 'while logged in as an admin' do
    let!(:admin) { log_in(:admin) }
    let(:user) { Fabricate(:user) }

    context 'index' do
      it 'returns success' do
        xhr :get, :index
        response.should be_success
      end
    end

    context 'create' do

      it 'requires a username_or_email parameter' do
	lambda { xhr :put, :create }.should raise_error(ActionController::ParameterMissing)
      end

      it 'returns 404 when that user does not exist' do
        xhr :post, :create, username_or_email: 'hedonismbot'
        response.status.should == 404
      end

      it "raises an invalid access error if the user can't be impersonated" do
        Guardian.any_instance.expects(:can_impersonate?).with(user).returns(false)
        xhr :post, :create, username_or_email: user.email
        response.should be_forbidden
      end

      context 'success' do

        it "changes the current user session id" do
          xhr :post, :create, username_or_email: user.username
          session[:current_user_id].should == user.id
        end

        it "returns success" do
          xhr :post, :create, username_or_email: user.email
          response.should be_success
        end

        it "also works with an email address" do
          xhr :post, :create, username_or_email: user.email
          session[:current_user_id].should == user.id
        end

      end

    end

  end



end
