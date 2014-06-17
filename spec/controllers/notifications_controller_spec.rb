require 'spec_helper'

describe NotificationsController do

  context 'when logged in' do
    let!(:user) { log_in }

    it 'should succeed' do
      xhr :get, :index
      response.should be_success
    end

    it 'should mark notifications as viewed' do
      notification = Fabricate(:notification, user: user)
      user.reload.unread_notifications.should == 1
      xhr :get, :index
      user.reload.unread_notifications.should == 0
    end

    it 'should not mark notifications as viewed if silent param is present' do
      notification = Fabricate(:notification, user: user)
      user.reload.unread_notifications.should == 1
      xhr :get, :index, silent: true
      user.reload.unread_notifications.should == 1
    end
  end

  context 'when not logged in' do
    it 'should raise an error' do
      lambda { xhr :get, :index }.should raise_error(Discourse::NotLoggedIn)
    end
  end

end
