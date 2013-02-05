require 'spec_helper'

describe Admin::UsersController do

  it "is a subclass of AdminController" do
    (Admin::UsersController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.index' do
      it 'returns success' do
        xhr :get, :index
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        ::JSON.parse(response.body).should be_present
      end    
    end

    context '.show' do
      it 'returns success' do
        xhr :get, :show, id: @user.username
        response.should be_success
      end
    end

    context '.approve_bulk' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it "does nothing without uesrs" do
        User.any_instance.expects(:approve).never
        xhr :put, :approve_bulk
      end

      it "won't approve the user when not allowed" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(false)
        User.any_instance.expects(:approve).never
        xhr :put, :approve_bulk, users: [evil_trout.id]
      end

      it "approves the user when permitted" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(true)
        User.any_instance.expects(:approve).once
        xhr :put, :approve_bulk, users: [evil_trout.id]
      end

    end

    context '.approve' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(false)
        xhr :put, :approve, user_id: evil_trout.id
        response.should be_forbidden
      end

      it 'calls approve' do
        User.any_instance.expects(:approve).with(@user)
        xhr :put, :approve, user_id: evil_trout.id
      end

    end

    context '.revoke_admin' do
      before do
        @another_admin = Fabricate(:another_admin)
      end

      it 'raises an error unless the user can revoke access' do
        Guardian.any_instance.expects(:can_revoke_admin?).with(@another_admin).returns(false)
        xhr :put, :revoke_admin, user_id: @another_admin.id
        response.should be_forbidden
      end

      it 'updates the admin flag' do        
        xhr :put, :revoke_admin, user_id: @another_admin.id
        @another_admin.reload
        @another_admin.should_not be_admin
      end
    end

    context '.grant_admin' do
      before do
        @another_user = Fabricate(:coding_horror)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_grant_admin?).with(@another_user).returns(false)
        xhr :put, :grant_admin, user_id: @another_user.id
        response.should be_forbidden
      end

      it "returns a 404 if the username doesn't exist" do        
        xhr :put, :grant_admin, user_id: 123123
        response.should be_forbidden
      end

      it 'updates the admin flag' do        
        xhr :put, :grant_admin, user_id: @another_user.id
        @another_user.reload
        @another_user.should be_admin
      end
    end

  end



end