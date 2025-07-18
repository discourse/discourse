# frozen_string_literal: true

require "rails_helper"

describe Jobs::DiscoursePostEventSendReminder do
  let(:admin_1) { Fabricate(:user, admin: true) }
  let(:going_user) { Fabricate(:user) }
  let(:interested_user) { Fabricate(:user) }
  let(:visited_going_user) { Fabricate(:user) }
  let(:not_going_user) { Fabricate(:user) }
  let(:going_user_unread_notification) { Fabricate(:user) }
  let(:going_user_read_notification) { Fabricate(:user) }
  let(:post_1) { Fabricate(:post) }
  let(:reminders) { "notification.5.minutes" }

  def init_invitees
    DiscoursePostEvent::Invitee.create_attendance!(going_user.id, event_1.id, :going)
    DiscoursePostEvent::Invitee.create_attendance!(interested_user.id, event_1.id, :interested)
    DiscoursePostEvent::Invitee.create_attendance!(not_going_user.id, event_1.id, :not_going)
    DiscoursePostEvent::Invitee.create_attendance!(
      going_user_unread_notification.id,
      event_1.id,
      :going,
    )
    DiscoursePostEvent::Invitee.create_attendance!(
      going_user_read_notification.id,
      event_1.id,
      :going,
    )
    DiscoursePostEvent::Invitee.create_attendance!(visited_going_user.id, event_1.id, :going)

    [
      going_user,
      interested_user,
      not_going_user,
      going_user_unread_notification,
      going_user_read_notification,
      visited_going_user,
    ].each { |user| user.notifications.update_all(read: true) }

    going_user_unread_notification.notifications.create!(
      notification_type: Notification.types[:event_reminder],
      topic_id: post_1.topic_id,
      post_number: 1,
      data: {}.to_json,
    )
  end

  before do
    freeze_time DateTime.parse("2018-11-10 12:00")

    Jobs.run_immediately!

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "#execute" do
    context "with invalid params" do
      it "raises an invalid parameters errors" do
        expect { Jobs::DiscoursePostEventSendReminder.new.execute(event_id: 1) }.to raise_error(
          Discourse::InvalidParameters,
        )

        expect { Jobs::DiscoursePostEventSendReminder.new.execute(reminder: "foo") }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end

    context "with deleted post" do
      let!(:event_1) do
        Fabricate(:event, post: post_1, reminders: reminders, original_starts_at: 3.hours.from_now)
      end

      it "is not erroring when post is already deleted" do
        post_1.delete

        expect {
          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )
        }.not_to raise_error
      end
    end

    context "with public event" do
      context "when event has not started" do
        let!(:event_1) do
          Fabricate(
            :event,
            post: post_1,
            reminders: reminders,
            original_starts_at: 3.hours.from_now,
          )
        end
        let!(:event_date_1) { Fabricate(:event_date, event: event_1, starts_at: 3.hours.from_now) }

        before { init_invitees }

        it "creates a new notification for going user" do
          expect(going_user.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.to change { going_user.reload.unread_notifications }.by(1)
        end

        it "doesn’t create a new notification for not going user" do
          expect(not_going_user.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.not_to change { not_going_user.reload.unread_notifications }
        end

        it "doesn’t create a new notification if there’s already one" do
          expect(going_user_unread_notification.unread_notifications).to eq(1)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.not_to change { going_user_unread_notification.reload.unread_notifications }
        end

        it "delete previous notifications before creating a new one" do
          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )
          going_user.notifications.update_all(read: true)

          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )

          expect(
            going_user
              .notifications
              .where(notification_type: Notification.types[:event_reminder])
              .count,
          ).to eq(1)
        end
      end

      context "when event has started" do
        let!(:event_1) do
          Fabricate(:event, post: post_1, reminders: reminders, original_starts_at: 3.hours.ago)
        end
        let!(:event_date_1) { Fabricate(:event_date, event: event_1, starts_at: 3.hours.ago) }

        before do
          init_invitees

          TopicUser.change(
            going_user,
            event_1.post.topic,
            last_visited_at: 4.hours.ago,
            last_read_post_number: 1,
          )
          TopicUser.change(
            visited_going_user,
            event_1.post.topic,
            last_visited_at: 2.minutes.ago,
            last_read_post_number: 1,
          )
        end

        it "creates a new notification for going user" do
          expect(going_user.reload.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.to change { going_user.reload.unread_notifications }.by(1)
        end

        it "creates a new notification for interested user" do
          expect(interested_user.reload.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.to change { interested_user.reload.unread_notifications }.by(1)
        end

        it "doesn’t create a new notification for not going user" do
          expect(not_going_user.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.not_to change { not_going_user.reload.unread_notifications }
        end

        it "doesn’t create a new notification if there’s already one" do
          expect(going_user_unread_notification.unread_notifications).to eq(1)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.not_to change { going_user_unread_notification.reload.unread_notifications }
        end

        it "deletes previous notifications when creating a new one" do
          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )
          going_user.notifications.update_all(read: true)

          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )

          expect(
            going_user
              .notifications
              .where(notification_type: Notification.types[:event_reminder])
              .count,
          ).to eq(1)
        end

        it "doesn't delete previous notifications if reminder type is different" do
          going_user.notifications.consolidate_or_create!(
            notification_type: Notification.types[:event_reminder],
            topic_id: post_1.topic_id,
            post_number: 1,
            read: true,
            data: {
              topic_title: event_1.name || post_1.topic.title,
              display_username: going_user.username,
              message: "discourse_post_event.notifications.before_event_reminder",
            }.to_json,
          )

          Jobs::DiscoursePostEventSendReminder.new.execute(
            event_id: event_1.id,
            reminder: reminders,
          )
          messages =
            Notification.where(
              user: going_user,
              notification_type: Notification.types[:event_reminder],
            ).pluck("data::json ->> 'message'")

          expect(messages).to contain_exactly(
            "discourse_post_event.notifications.before_event_reminder",
            "discourse_post_event.notifications.ongoing_event_reminder",
          )
        end

        it "doesn’t create a new notification for visiting user" do
          expect(visited_going_user.unread_notifications).to eq(0)

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(
              event_id: event_1.id,
              reminder: reminders,
            )
          }.not_to change { visited_going_user.reload.unread_notifications }
        end
      end
    end
  end
end
