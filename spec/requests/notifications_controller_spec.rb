# frozen_string_literal: true

def create_notification(user_id, resp_code, matcher)
  notification_count = Notification.count
  post "/notifications.json",
       params: {
         notification_type: Notification.types[:mentioned],
         user_id: user_id,
         data: { message: "tada" }.to_json,
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
  context "when logged in" do
    context "as normal user" do
      fab!(:user) { sign_in(Fabricate(:user)) }
      fab!(:acting_user) { Fabricate(:user) }
      fab!(:notification) do
        Fabricate(:notification, user: user, data: { username: acting_user.username }.to_json)
      end

      describe "#index" do
        it "should succeed for recent" do
          get "/notifications", params: { recent: true }
          expect(response.status).to eq(200)
        end

        it "should succeed for history" do
          get "/notifications.json"

          expect(response.status).to eq(200)

          notifications = response.parsed_body["notifications"]

          expect(notifications.length).to eq(1)
          expect(notifications.first["id"]).to eq(notification.id)
        end

        it "should mark notifications as viewed" do
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)

          get "/notifications.json", params: { recent: true }

          expect(response.status).to eq(200)
          expect(user.reload.unread_notifications).to eq(0)
          expect(user.reload.total_unread_notifications).to eq(1)
        end

        it "should not mark notifications as viewed if silent param is present" do
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)

          get "/notifications.json", params: { recent: true, silent: true }

          expect(response.status).to eq(200)
          expect(user.reload.unread_notifications).to eq(1)
          expect(user.reload.total_unread_notifications).to eq(1)
        end

        it "should not mark notifications as viewed in readonly mode" do
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

        describe "when limit params is invalid" do
          include_examples "invalid limit params",
                           "/notifications.json",
                           described_class::INDEX_LIMIT + 1,
                           params: {
                             recent: true,
                           }
        end

        it "respects limit param and properly bumps offset for load_more_notifications URL" do
          7.times { notification = Fabricate(:notification, user: user) }

          get "/notifications.json", params: { username: user.username, limit: 2 }
          expect(response.parsed_body["notifications"].count).to eq(2)
          expect(response.parsed_body["load_more_notifications"]).to eq(
            "/notifications?limit=2&offset=2&username=#{user.username}",
          )

          # Same as response above but we need .json added before query params.
          get "/notifications.json?limit=2&offset=2&username=#{user.username}"
          expect(response.parsed_body["load_more_notifications"]).to eq(
            "/notifications?limit=2&offset=4&username=#{user.username}",
          )

          # We are seeing that the offset is increasing properly and limit is staying the same
          get "/notifications.json?limit=2&offset=4&username=#{user.username}"
          expect(response.parsed_body["load_more_notifications"]).to eq(
            "/notifications?limit=2&offset=6&username=#{user.username}",
          )
        end

        it "get notifications with all filters" do
          notification = Fabricate(:notification, user: user)
          notification2 = Fabricate(:notification, user: user)
          put "/notifications/mark-read.json", params: { id: notification.id }
          expect(response.status).to eq(200)

          get "/notifications.json"

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["notifications"].length).to be >= 2

          get "/notifications.json", params: { filter: "read" }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["notifications"].length).to be >= 1
          expect(JSON.parse(response.body)["notifications"][0]["read"]).to eq(true)

          get "/notifications.json", params: { filter: "unread" }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["notifications"].length).to be >= 1
          expect(JSON.parse(response.body)["notifications"][0]["read"]).to eq(false)
        end

        context "when navigation menu settings is non-legacy" do
          fab!(:unread_high_priority) do
            Fabricate(
              :notification,
              user: user,
              high_priority: true,
              read: false,
              created_at: 10.minutes.ago,
            )
          end

          fab!(:read_high_priority) do
            Fabricate(
              :notification,
              user: user,
              high_priority: true,
              read: true,
              created_at: 8.minutes.ago,
            )
          end

          fab!(:unread_regular) do
            Fabricate(
              :notification,
              user: user,
              high_priority: false,
              read: false,
              created_at: 6.minutes.ago,
            )
          end

          fab!(:read_regular) do
            Fabricate(
              :notification,
              user: user,
              high_priority: false,
              read: true,
              created_at: 4.minutes.ago,
            )
          end

          fab!(:pending_reviewable) { Fabricate(:reviewable) }

          before { SiteSetting.navigation_menu = "sidebar" }

          it "gets notifications list with unread ones at the top" do
            get "/notifications.json", params: { recent: true }

            expect(response.status).to eq(200)

            expect(response.parsed_body["notifications"].map { |n| n["id"] }).to eq(
              [
                unread_high_priority.id,
                notification.id,
                unread_regular.id,
                read_regular.id,
                read_high_priority.id,
              ],
            )
          end

          it "should not bump last seen reviewable in readonly mode" do
            user.update!(admin: true)

            Discourse.received_redis_readonly!

            expect {
              get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }
              expect(response.status).to eq(200)
            }.not_to change { user.reload.last_seen_reviewable_id }
          ensure
            Discourse.clear_redis_readonly!
          end

          it "should not bump last seen reviewable if the user can't see reviewables" do
            expect {
              get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }
              expect(response.status).to eq(200)
            }.not_to change { user.reload.last_seen_reviewable_id }
          end

          it "should not bump last seen reviewable if the silent param is present" do
            user.update!(admin: true)

            expect {
              get "/notifications.json",
                  params: {
                    recent: true,
                    silent: true,
                    bump_last_seen_reviewable: true,
                  }
              expect(response.status).to eq(200)
            }.not_to change { user.reload.last_seen_reviewable_id }
          end

          it "should not bump last seen reviewable if the bump_last_seen_reviewable param is not present" do
            user.update!(admin: true)

            expect {
              get "/notifications.json", params: { recent: true }
              expect(response.status).to eq(200)
            }.not_to change { user.reload.last_seen_reviewable_id }
          end

          it "bumps last_seen_reviewable_id" do
            user.update!(admin: true)

            expect(user.last_seen_reviewable_id).to eq(nil)

            get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }

            expect(response.status).to eq(200)
            expect(user.reload.last_seen_reviewable_id).to eq(pending_reviewable.id)

            reviewable2 = Fabricate(:reviewable)

            get "/notifications.json", params: { recent: true, bump_last_seen_reviewable: true }

            expect(response.status).to eq(200)
            expect(user.reload.last_seen_reviewable_id).to eq(reviewable2.id)
          end

          it "includes pending reviewables when the setting is enabled" do
            user.update!(admin: true)
            pending_reviewable2 = Fabricate(:reviewable, created_at: 4.minutes.ago)
            Fabricate(:reviewable, status: Reviewable.statuses[:approved])
            Fabricate(:reviewable, status: Reviewable.statuses[:rejected])

            get "/notifications.json", params: { recent: true }

            expect(response.status).to eq(200)

            expect(response.parsed_body["pending_reviewables"].map { |r| r["id"] }).to eq(
              [pending_reviewable.id, pending_reviewable2.id],
            )
          end

          it "doesn't include reviewables that are claimed by someone that's not the current user" do
            user.update!(admin: true)

            claimed_by_user =
              Fabricate(:reviewable, topic: Fabricate(:topic), created_at: 5.minutes.ago)
            Fabricate(:reviewable_claimed_topic, topic: claimed_by_user.topic, user: user)

            user2 = Fabricate(:user)
            claimed_by_user2 = Fabricate(:reviewable, topic: Fabricate(:topic))
            Fabricate(:reviewable_claimed_topic, topic: claimed_by_user2.topic, user: user2)

            unclaimed = Fabricate(:reviewable, topic: Fabricate(:topic), created_at: 10.minutes.ago)

            get "/notifications.json", params: { recent: true }
            expect(response.status).to eq(200)
            expect(response.parsed_body["pending_reviewables"].map { |r| r["id"] }).to eq(
              [pending_reviewable.id, claimed_by_user.id, unclaimed.id],
            )
          end

          it "doesn't include reviewables if the user can't see the review queue" do
            user.update!(admin: false)

            get "/notifications.json", params: { recent: true }
            expect(response.status).to eq(200)
            expect(response.parsed_body.key?("pending_reviewables")).to eq(false)
          end
        end

        context "when filter_by_types param is present" do
          fab!(:liked1) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:liked],
              created_at: 2.minutes.ago,
            )
          end
          fab!(:liked2) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:liked],
              created_at: 10.minutes.ago,
            )
          end
          fab!(:replied) do
            Fabricate(
              :notification,
              user: user,
              notification_type: Notification.types[:replied],
              created_at: 7.minutes.ago,
            )
          end
          fab!(:mentioned) do
            Fabricate(:notification, user: user, notification_type: Notification.types[:mentioned])
          end

          it "correctly filters notifications to the type(s) given" do
            get "/notifications.json", params: { recent: true, filter_by_types: "liked,replied" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["notifications"].map { |n| n["id"] }).to eq(
              [liked1.id, replied.id, liked2.id],
            )

            get "/notifications.json", params: { recent: true, filter_by_types: "replied" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["notifications"].map { |n| n["id"] }).to eq([replied.id])
          end

          it "doesn't include notifications from other users" do
            Fabricate(
              :notification,
              user: Fabricate(:user),
              notification_type: Notification.types[:liked],
            )
            get "/notifications.json", params: { recent: true, filter_by_types: "liked" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["notifications"].map { |n| n["id"] }).to eq(
              [liked1.id, liked2.id],
            )
          end

          it "limits the number of returned notifications according to the limit param" do
            get "/notifications.json", params: { recent: true, filter_by_types: "liked", limit: 1 }
            expect(response.status).to eq(200)
            expect(response.parsed_body["notifications"].map { |n| n["id"] }).to eq([liked1.id])
          end
        end

        context "when username params is not valid" do
          it "should raise the right error" do
            get "/notifications.json", params: { username: "somedude" }
            expect(response.status).to eq(404)
          end
        end

        context "with notifications for inaccessible topics" do
          fab!(:sender) { Fabricate.build(:topic_allowed_user, user: Fabricate(:coding_horror)) }
          fab!(:allowed_user) { Fabricate.build(:topic_allowed_user, user: user) }
          fab!(:another_allowed_user) do
            Fabricate.build(:topic_allowed_user, user: Fabricate(:user))
          end
          fab!(:allowed_pm) do
            Fabricate(
              :private_message_topic,
              topic_allowed_users: [sender, allowed_user, another_allowed_user],
            )
          end
          fab!(:forbidden_pm) do
            Fabricate(:private_message_topic, topic_allowed_users: [sender, another_allowed_user])
          end
          fab!(:allowed_pm_notification) do
            Fabricate(:private_message_notification, user: user, topic: allowed_pm)
          end
          fab!(:forbidden_pm_notification) do
            Fabricate(:private_message_notification, user: user, topic: forbidden_pm)
          end

          def expect_correct_notifications(response)
            notification_ids = response.parsed_body["notifications"].map { |n| n["id"] }
            expect(notification_ids).to include(allowed_pm_notification.id)
            expect(notification_ids).to_not include(forbidden_pm_notification.id)
          end

          context "with 'recent' filter" do
            it "doesn't include notifications from topics the user isn't allowed to see" do
              SiteSetting.navigation_menu = "sidebar"

              get "/notifications.json", params: { recent: true }
              expect(response.status).to eq(200)
              expect_correct_notifications(response)
            end
          end

          context "without 'recent' filter" do
            it "doesn't include notifications from topics the user isn't allowed to see" do
              SiteSetting.navigation_menu = "sidebar"

              get "/notifications.json"
              expect(response.status).to eq(200)
              expect_correct_notifications(response)
            end
          end
        end

        context "with `show_user_menu_avatars` setting enabled" do
          before { SiteSetting.show_user_menu_avatars = true }

          it "serializes acting_user_avatar_template into notifications" do
            get "/notifications.json"

            notifications = response.parsed_body["notifications"]
            expect(notifications).not_to be_empty
            notifications.each do |notification|
              expect(notification["acting_user_avatar_template"]).to be_present
            end
          end
        end
      end

      it "should succeed" do
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

      describe "#create" do
        it "can't create notification" do
          create_notification(user.id, 403, :to)
        end
      end

      describe "#update" do
        it "can't update notification" do
          update_notification(Fabricate(:topic).id, 403, :to_not)
        end
      end

      describe "#destroy" do
        it "can't delete notification" do
          delete_notification(403, :to)
        end
      end

      describe "#mark_read" do
        context "when targeting a notification by id" do
          it "can mark a notification as read" do
            expect {
              put "/notifications/mark-read.json", params: { id: notification.id }
              expect(response.status).to eq(200)
              notification.reload
            }.to change { notification.read }.from(false).to(true)
          end

          it "doesn't mark a notification of another user as read" do
            notification.update!(user_id: Fabricate(:user).id, read: false)
            expect {
              put "/notifications/mark-read.json", params: { id: notification.id }
              expect(response.status).to eq(200)
              notification.reload
            }.not_to change { notification.read }
          end
        end

        context "when targeting notifications by type" do
          it "can mark notifications as read" do
            replied1 = notification
            replied1.update!(notification_type: Notification.types[:replied])
            mentioned =
              Fabricate(
                :notification,
                user: user,
                notification_type: Notification.types[:mentioned],
                read: false,
              )
            liked =
              Fabricate(
                :notification,
                user: user,
                notification_type: Notification.types[:liked],
                read: false,
              )
            replied2 =
              Fabricate(
                :notification,
                user: user,
                notification_type: Notification.types[:replied],
                read: true,
              )
            put "/notifications/mark-read.json", params: { dismiss_types: "replied,mentioned" }
            expect(response.status).to eq(200)
            expect(replied1.reload.read).to eq(true)
            expect(replied2.reload.read).to eq(true)
            expect(mentioned.reload.read).to eq(true)

            expect(liked.reload.read).to eq(false)
          end

          it "doesn't mark notifications of another user as read" do
            mentioned1 =
              Fabricate(
                :notification,
                user: user,
                notification_type: Notification.types[:mentioned],
                read: false,
              )
            mentioned2 =
              Fabricate(
                :notification,
                user: Fabricate(:user),
                notification_type: Notification.types[:mentioned],
                read: false,
              )
            put "/notifications/mark-read.json", params: { dismiss_types: "mentioned" }
            expect(mentioned1.reload.read).to eq(true)
            expect(mentioned2.reload.read).to eq(false)
          end
        end
      end
    end

    context "as admin" do
      fab!(:admin) { sign_in(Fabricate(:admin)) }

      describe "#create" do
        it "can create notification" do
          create_notification(admin.id, 200, :to_not)
          expect(response.parsed_body["id"]).to_not eq(nil)
        end
      end

      describe "#update" do
        it "can update notification" do
          update_notification(8, 200, :to)
          expect(response.parsed_body["topic_id"]).to eq(8)
        end
      end

      describe "#destroy" do
        it "can delete notification" do
          delete_notification(200, :to_not)
        end
      end
    end
  end

  context "when not logged in" do
    describe "#index" do
      it "should raise an error" do
        get "/notifications.json", params: { recent: true }
        expect(response.status).to eq(403)
      end
    end

    describe "#create" do
      it "can't create notification" do
        user = Fabricate(:user)
        create_notification(user.id, 403, :to)
      end
    end

    describe "#update" do
      it "can't update notification" do
        update_notification(Fabricate(:topic).id, 403, :to_not)
      end
    end

    describe "#destroy" do
      it "can't delete notification" do
        delete_notification(403, :to)
      end
    end

    describe "#totals" do
      it "can't see notification totals" do
        get "/notifications/totals.json"
        expect(response.status).to eq(403)
      end
    end
  end

  context "with user api keys" do
    fab!(:user)
    let(:user_api_key) do
      UserApiKey.create!(
        scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
        user_id: user.id,
      )
    end

    before { SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0] }

    it "allows access to notifications#totals" do
      get "/notifications/totals.json", headers: { "User-Api-Key": user_api_key.key }
      expect(response.status).to eq(200)
    end

    it "allows access to notifications#index" do
      get "/notifications.json", headers: { "User-Api-Key": user_api_key.key }
      expect(response.status).to eq(200)
    end
  end
end
