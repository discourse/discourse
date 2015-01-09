require 'spec_helper'

describe NotificationsController do

  context 'when logged in' do
    let!(:user) { log_in }

    it 'should succeed for recent' do
      xhr :get, :recent
      expect(response).to be_success
    end

    it 'should succeed for history' do
      xhr :get, :history
      expect(response).to be_success
    end

    it 'should succeed for history' do
      xhr :get, :reset_new
      expect(response).to be_success
    end

    it 'should mark notifications as viewed' do
      notification = Fabricate(:notification, user: user)
      expect(user.reload.unread_notifications).to eq(1)
      expect(user.reload.total_unread_notifications).to eq(1)
      xhr :get, :recent
      expect(user.reload.unread_notifications).to eq(0)
      expect(user.reload.total_unread_notifications).to eq(1)
    end

    it 'should not mark notifications as viewed if silent param is present' do
      notification = Fabricate(:notification, user: user)
      expect(user.reload.unread_notifications).to eq(1)
      expect(user.reload.total_unread_notifications).to eq(1)
      xhr :get, :recent, silent: true
      expect(user.reload.unread_notifications).to eq(1)
      expect(user.reload.total_unread_notifications).to eq(1)
    end

    it "updates the `read` status" do
      notification = Fabricate(:notification, user: user)
      expect(user.reload.unread_notifications).to eq(1)
      expect(user.reload.total_unread_notifications).to eq(1)
      xhr :put, :reset_new
      user.reload
      expect(user.reload.unread_notifications).to eq(0)
      expect(user.reload.total_unread_notifications).to eq(0)
    end
  end

  context 'when not logged in' do
    it 'should raise an error' do
      expect { xhr :get, :recent }.to raise_error(Discourse::NotLoggedIn)
    end
  end

end
