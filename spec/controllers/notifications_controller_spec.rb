require 'rails_helper'

def create_notification(user_id, resp_code, matcher)
  notification_count = Notification.count
  post :create, params: { notification_type: Notification.types[:mentioned], user_id: user_id, data: { message: 'tada' }.to_json }, format: :json
  expect(response.status).to eq(resp_code)
  expect(Notification.count).send(matcher, eq(notification_count))
end

def update_notification(topic_id, resp_code, matcher)
  notification = Fabricate(:notification)
  post :update, params: { id: notification.id, topic_id: topic_id }, format: :json
  expect(response.status).to eq(resp_code)
  notification.reload
  expect(notification.topic_id).send(matcher, eq(topic_id))
end

def delete_notification(resp_code, matcher)
  notification = Fabricate(:notification)
  notification_count = Notification.count
  delete :destroy, params: { id: notification.id }, format: :json
  expect(response.status).to eq(resp_code)
  expect(Notification.count).send(matcher, eq(notification_count))
end

describe NotificationsController do

  context 'when logged in' do

    context 'as normal user' do

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
          _notification = Fabricate(:notification, user: user)
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)
          get :index, params: { recent: true }, format: :json
          expect(user.reload.unread_notifications).to eq(0)
          expect(user.reload.total_unread_notifications).to eq(1)
        end

        it 'should not mark notifications as viewed if silent param is present' do
          _notification = Fabricate(:notification, user: user)
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
        _notification = Fabricate(:notification, user: user)
        expect(user.reload.unread_notifications).to eq(1)
        expect(user.reload.total_unread_notifications).to eq(1)
        put :mark_read, format: :json
        user.reload
        expect(user.reload.unread_notifications).to eq(0)
        expect(user.reload.total_unread_notifications).to eq(0)
      end

      describe '#create' do
        it "can't create notification" do
          create_notification(user.id, 403, :to)
        end
      end

      describe '#update' do
        it "can't update notification" do
          update_notification(8, 403, :to_not)
        end
      end

      describe '#destroy' do
        it "can't delete notification" do
          delete_notification(403, :to)
        end
      end

    end

    context 'as admin' do

      let!(:admin) { log_in(:admin) }

      describe '#create' do
        it "can create notification" do
          create_notification(admin.id, 200, :to_not)
          expect(::JSON.parse(response.body)["id"]).to_not eq(nil)
        end
      end

      describe '#update' do
        it "can update notification" do
          update_notification(8, 200, :to)
          expect(::JSON.parse(response.body)["topic_id"]).to eq(8)
        end
      end

      describe '#destroy' do
        it "can delete notification" do
          delete_notification(200, :to_not)
        end
      end

    end

  end

  context 'when not logged in' do

    describe '#index' do
      it 'should raise an error' do
        get :index, params: { recent: true }, format: :json
        expect(response.status).to eq(403)
      end
    end

    describe '#create' do
      it "can't create notification" do
        user = Fabricate(:user)
        create_notification(user.id, 403, :to)
      end
    end

    describe '#update' do
      it "can't update notification" do
        update_notification(8, 403, :to_not)
      end
    end

    describe '#destroy' do
      it "can't delete notification" do
        delete_notification(403, :to)
      end
    end

  end

end
