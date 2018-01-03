require 'rails_helper'

describe NotificationsController do

  context 'when logged in' do
    let!(:user) { log_in }

    describe '#index' do
      it 'should succeed for recent' do
        get :index, params: { recent: true }
        expect(response).to be_success
      end

      it 'should succeed for history' do
        get :index
        expect(response).to be_success
      end

      it 'should mark notifications as viewed' do
        notification = Fabricate(:notification, user: user)
        expect(user.reload.unread_notifications).to eq(1)
        expect(user.reload.total_unread_notifications).to eq(1)
        get :index, params: { recent: true }, format: :json
        expect(user.reload.unread_notifications).to eq(0)
        expect(user.reload.total_unread_notifications).to eq(1)
      end

      it 'should not mark notifications as viewed if silent param is present' do
        notification = Fabricate(:notification, user: user)
        expect(user.reload.unread_notifications).to eq(1)
        expect(user.reload.total_unread_notifications).to eq(1)
        get :index, params: { recent: true, silent: true }
        expect(user.reload.unread_notifications).to eq(1)
        expect(user.reload.total_unread_notifications).to eq(1)
      end

      context 'when username params is not valid' do
        it 'should raise the right error' do
          get :index, params: { username: 'somedude' }, format: :json

          expect(response).to_not be_success
          expect(response.status).to eq(404)
        end
      end
    end

    it 'should succeed' do
      put :mark_read, format: :json
      expect(response).to be_success
    end

    it "can update a single notification" do
      notification = Fabricate(:notification, user: user)
      notification2 = Fabricate(:notification, user: user)
      put :mark_read, params: { id: notification.id }, format: :json
      expect(response).to be_success

      notification.reload
      notification2.reload

      expect(notification.read).to eq(true)
      expect(notification2.read).to eq(false)
    end

    it "updates the `read` status" do
      notification = Fabricate(:notification, user: user)
      expect(user.reload.unread_notifications).to eq(1)
      expect(user.reload.total_unread_notifications).to eq(1)
      put :mark_read, format: :json
      user.reload
      expect(user.reload.unread_notifications).to eq(0)
      expect(user.reload.total_unread_notifications).to eq(0)
    end
  end

  context 'when not logged in' do
    it 'should raise an error' do
      expect do
        get :index, params: { recent: true }, format: :json
      end.to raise_error(Discourse::NotLoggedIn)
    end
  end

end
