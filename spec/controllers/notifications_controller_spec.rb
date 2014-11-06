require 'spec_helper'

describe NotificationsController do

  context 'when logged in' do
    let!(:user) { log_in }

    it 'should succeed for recent' do
      xhr :get, :recent
      response.should be_success
    end

    it 'should succeed for history' do
      xhr :get, :history
      response.should be_success
    end

    it 'should succeed for history' do
      xhr :get, :reset_new
      response.should be_success
    end

    it 'should mark notifications as viewed' do
      notification = Fabricate(:notification, user: user)
      user.reload.unread_notifications.should == 1
      user.reload.total_unread_notifications.should == 1
      xhr :get, :recent
      user.reload.unread_notifications.should == 0
      user.reload.total_unread_notifications.should == 1
    end

    it 'should not mark notifications as viewed if silent param is present' do
      notification = Fabricate(:notification, user: user)
      user.reload.unread_notifications.should == 1
      user.reload.total_unread_notifications.should == 1
      xhr :get, :recent, silent: true
      user.reload.unread_notifications.should == 1
      user.reload.total_unread_notifications.should == 1
    end

    it "updates the `read` status" do
      notification = Fabricate(:notification, user: user)
      user.reload.unread_notifications.should == 1
      user.reload.total_unread_notifications.should == 1
      xhr :put, :reset_new
      user.reload
      user.reload.unread_notifications.should == 0
      user.reload.total_unread_notifications.should == 0
    end
  end

  context 'when not logged in' do
    it 'should raise an error' do
      lambda { xhr :get, :recent }.should raise_error(Discourse::NotLoggedIn)
    end
  end

end
