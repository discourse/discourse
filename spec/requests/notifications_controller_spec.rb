# frozen_string_literal: true

def create_notification(user_id, resp_code, matcher)
  notification_count = Notification.count
  post "/notifications.json",
    params: {
      notification_type: Notification.types[:mentioned],
      user_id: user_id,
      data: { message: 'tada' }.to_json
    }
  expect(response.status).to eq(resp_code)
  expect(Notification.count).public_send(matcher, eq(notification_count))
end

def update_notification(topic_id, resp_code, matcher)
  notification = Fabricate(:notification)
  put "/notifications/#{notification.id}.json", params: { topic_id: topic_id }
  expect(response.status).to eq(resp_code)
  notification.reload
  expect(notification.topic_id).public_send(matcher, eq(topic_id))
end

def delete_notification(resp_code, matcher)
  notification = Fabricate(:notification)
  notification_count = Notification.count
  delete "/notifications/#{notification.id}.json"
  expect(response.status).to eq(resp_code)
  expect(Notification.count).public_send(matcher, eq(notification_count))
end

RSpec.describe NotificationsController do
  context 'when logged in' do
    context 'as normal user' do
      fab!(:user) { sign_in(Fabricate(:user)) }
      fab!(:notification) { Fabricate(:notification, user: user) }

      describe '#index' do
        it 'should succeed for recent' do
          get "/notifications", params: { recent: true }
          expect(response.status).to eq(200)
        end

        it 'should succeed for history' do
          get "/notifications.json"

          expect(response.status).to eq(200)

          notifications = response.parsed_body["notifications"]

          expect(notifications.length).to eq(1)
          expect(notifications.first["id"]).to eq(notification.id)
        end

        it 'should mark notifications as viewed' do
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)

          get "/notifications.json", params: { recent: true }

          expect(response.status).to eq(200)
          expect(user.reload.unread_notifications).to eq(0)
          expect(user.reload.total_unread_notifications).to eq(1)
        end

        it 'should not mark notifications as viewed if silent param is present' do
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)

          get "/notifications.json", params: { recent: true, silent: true }

          expect(response.status).to eq(200)
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)
        end

        it 'should not mark notifications as viewed in readonly mode' do
          Discourse.received_redis_readonly!
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)

          get "/notifications.json", params: { recent: true, silent: true }

          expect(response.status).to eq(200)
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)
        ensure
          Discourse.clear_redis_readonly!
        end

        it "should not bump last seen reviewable in readonly mode" do
          user.update!(admin: true)
          Fabricate(:reviewable)
          Discourse.received_redis_readonly!
          expect {
            get "/notifications.json", params: { recent: true }
            expect(response.status).to eq(200)
          }.not_to change { user.reload.last_seen_reviewable_id }
        ensure
          Discourse.clear_redis_readonly!
        end

        it "should not bump last seen reviewable if the user can't seen reviewables" do
          Fabricate(:reviewable)
          expect {
            get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }
            expect(response.status).to eq(200)
          }.not_to change { user.reload.last_seen_reviewable_id }
        end

        it "should not bump last seen reviewable if the silent param is present" do
          user.update!(admin: true)
          Fabricate(:reviewable)
          expect {
            get "/notifications.json", params: {
              recent: true,
              silent: true,
              bump_last_seen_reviewable: true
            }
            expect(response.status).to eq(200)
          }.not_to change { user.reload.last_seen_reviewable_id }
        end

        it "should not bump last seen reviewable if the bump_last_seen_reviewable param is not present" do
          user.update!(admin: true)
          Fabricate(:reviewable)
          expect {
            get "/notifications.json", params: { recent: true, silent: true }
            expect(response.status).to eq(200)
          }.not_to change { user.reload.last_seen_reviewable_id }
        end

        it "bumps last_seen_reviewable_id" do
          user.update!(admin: true)
          expect(user.last_seen_reviewable_id).to eq(nil)
          reviewable = Fabricate(:reviewable)
          get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }
          expect(user.reload.last_seen_reviewable_id).to eq(reviewable.id)

          reviewable2 = Fabricate(:reviewable)
          get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }
          expect(user.reload.last_seen_reviewable_id).to eq(reviewable2.id)
        end

        it "get notifications with all filters" do
          notification = Fabricate(:notification, user: user)
          notification2 = Fabricate(:notification, user: user)
          put "/notifications/mark-read.json", params: { id: notification.id }
          expect(response.status).to eq(200)

          get "/notifications.json"

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['notifications'].length).to be >= 2

          get "/notifications.json", params: { filter: "read" }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['notifications'].length).to be >= 1
          expect(JSON.parse(response.body)['notifications'][0]['read']).to eq(true)

          get "/notifications.json", params: { filter: "unread" }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['notifications'].length).to be >= 1
          expect(JSON.parse(response.body)['notifications'][0]['read']).to eq(false)
        end

        context "when filter_by_types param is present" do
          fab!(:liked1) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:liked],
              created_at: 2.minutes.ago
            )
          end
          fab!(:liked2) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:liked],
              created_at: 10.minutes.ago
            )
          end
          fab!(:replied) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:replied],
              created_at: 7.minutes.ago
            )
          end
          fab!(:mentioned) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:mentioned]
            )
          end

          it "correctly filters notifications to the type(s) given" do
            get "/notifications.json", params: { recent: true, filter_by_types: "liked,replied" }
            expect(response.status).to eq(200)
            expect(
              response.parsed_body["notifications"].map { |n| n["id"] }
            ).to eq([liked1.id, replied.id, liked2.id])

            get "/notifications.json", params: { recent: true, filter_by_types: "replied" }
            expect(response.status).to eq(200)
            expect(
              response.parsed_body["notifications"].map { |n| n["id"] }
            ).to eq([replied.id])
          end

          it "doesn't include notifications from other users" do
            Fabricate(
              :notification,
              user: Fabricate(:user),
              notification_type: Notification.types[:liked]
            )
            get "/notifications.json", params: { recent: true, filter_by_types: "liked" }
            expect(response.status).to eq(200)
            expect(
              response.parsed_body["notifications"].map { |n| n["id"] }
            ).to eq([liked1.id, liked2.id])
          end

          it "limits the number of returned notifications according to the limit param" do
            get "/notifications.json", params: { recent: true, filter_by_types: "liked", limit: 1 }
            expect(response.status).to eq(200)
            expect(
              response.parsed_body["notifications"].map { |n| n["id"] }
            ).to eq([liked1.id])
          end
        end

        context 'when username params is not valid' do
          it 'should raise the right error' do
            get "/notifications.json", params: { username: 'somedude' }
            expect(response.status).to eq(404)
          end
        end
      end

      it 'should succeed' do
        put "/notifications/mark-read.json"
        expect(response.status).to eq(200)
      end

      it "can update a single notification" do
        notification2 = Fabricate(:notification, user: user)
        put "/notifications/mark-read.json", params: { id: notification.id }
        expect(response.status).to eq(200)

        notification.reload
        notification2.reload

        expect(notification.read).to eq(true)
        expect(notification2.read).to eq(false)
      end

      it "updates the `read` status" do
        expect(user.reload.unread_notifications).to eq(1)
        expect(user.reload.total_unread_notifications).to eq(1)

        put "/notifications/mark-read.json"

        expect(response.status).to eq(200)
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
          update_notification(Fabricate(:topic).id, 403, :to_not)
        end
      end

      describe '#destroy' do
        it "can't delete notification" do
          delete_notification(403, :to)
        end
      end
    end

    context 'as admin' do
      fab!(:admin) { sign_in(Fabricate(:admin)) }

      describe '#create' do
        it "can create notification" do
          create_notification(admin.id, 200, :to_not)
          expect(response.parsed_body["id"]).to_not eq(nil)
        end
      end

      describe '#update' do
        it "can update notification" do
          update_notification(8, 200, :to)
          expect(response.parsed_body["topic_id"]).to eq(8)
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
        get "/notifications.json", params: { recent: true }
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
        update_notification(Fabricate(:topic).id, 403, :to_not)
      end
    end

    describe '#destroy' do
      it "can't delete notification" do
        delete_notification(403, :to)
      end
    end
  end
end
