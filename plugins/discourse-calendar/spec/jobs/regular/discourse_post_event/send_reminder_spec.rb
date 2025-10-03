# frozen_string_literal: true

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

    context "with recurring event" do
      let!(:recurring_event) do
        Fabricate(
          :event,
          post: post_1,
          reminders: reminders,
          original_starts_at: 3.hours.from_now,
          original_ends_at: 4.hours.from_now,
          recurrence: "every_day",
        )
      end

      let(:expired_event) do
        Fabricate(
          :event,
          post: Fabricate(:post),
          reminders: reminders,
          original_starts_at: 1.day.ago,
          original_ends_at: 1.day.ago + 1.hour,
          recurrence: "every_day",
          recurrence_until: 1.hour.ago,
        )
      end

      before do
        setup_recurring_event_invitees
        clear_notifications
      end

      def setup_recurring_event_invitees
        DiscoursePostEvent::Invitee.create_attendance!(going_user.id, recurring_event.id, :going)
        DiscoursePostEvent::Invitee.create_attendance!(
          interested_user.id,
          recurring_event.id,
          :interested,
        )
        DiscoursePostEvent::Invitee.create_attendance!(
          not_going_user.id,
          recurring_event.id,
          :not_going,
        )
        DiscoursePostEvent::Invitee.create_attendance!(
          going_user_unread_notification.id,
          recurring_event.id,
          :going,
        )
        DiscoursePostEvent::Invitee.create_attendance!(
          going_user_read_notification.id,
          recurring_event.id,
          :going,
        )
        DiscoursePostEvent::Invitee.create_attendance!(
          visited_going_user.id,
          recurring_event.id,
          :going,
        )
      end

      def clear_notifications
        all_users.each { |user| user.notifications.delete_all }
        going_user_unread_notification.notifications.create!(
          notification_type: Notification.types[:event_reminder],
          topic_id: post_1.topic_id,
          post_number: 1,
          data: {}.to_json,
        )
      end

      def all_users
        [
          going_user,
          interested_user,
          not_going_user,
          going_user_unread_notification,
          going_user_read_notification,
          visited_going_user,
        ]
      end

      def send_reminder(event = recurring_event)
        Jobs::DiscoursePostEventSendReminder.new.execute(event_id: event.id, reminder: reminders)
      end

      def advance_to_next_occurrence
        freeze_time(recurring_event.original_starts_at + 1.day + 1.hour)
        recurring_event.event_dates.pending.update_all(finished_at: Time.current - 1.hour)
        recurring_event.set_next_date
      end

      it "sends reminders for the first occurrence" do
        recurring_event.set_next_date

        expect { send_reminder }.to change { going_user.reload.unread_notifications }.by(1)
      end

      it "sends reminders for subsequent occurrences" do
        recurring_event.set_next_date
        first_event_date = recurring_event.event_dates.pending.first

        send_reminder
        going_user.notifications.update_all(read: true)

        advance_to_next_occurrence

        next_event_date = recurring_event.event_dates.pending.first
        expect(next_event_date).to be_present
        expect(next_event_date.id).not_to eq(first_event_date.id)

        expect { send_reminder }.to change { going_user.reload.unread_notifications }.by(1)
      end

      it "handles timezone-specific events" do
        recurring_event.update!(timezone: "America/Los_Angeles")
        recurring_event.set_next_date

        expect { send_reminder }.to change { going_user.reload.unread_notifications }.by(1)

        going_user.notifications.update_all(read: true)
        advance_to_next_occurrence

        expect { send_reminder }.to change { going_user.reload.unread_notifications }.by(1)
      end

      it "correctly determines event status across timezones" do
        tokyo_timezone = "Asia/Tokyo"

        tokyo_time = Time.current.in_time_zone(tokyo_timezone) + 30.minutes

        timezone_event =
          Fabricate(
            :event,
            post: Fabricate(:post),
            reminders: "notification.15.minutes",
            original_starts_at: tokyo_time.to_time,
            original_ends_at: tokyo_time.to_time + 1.hour,
            timezone: tokyo_timezone,
          )

        DiscoursePostEvent::Invitee.create_attendance!(going_user.id, timezone_event.id, :going)
        going_user.notifications.delete_all

        expect { send_reminder(timezone_event) }.to change {
          going_user.reload.unread_notifications
        }.by(1)

        notification = going_user.notifications.last
        expect(JSON.parse(notification.data)["message"]).to eq(
          "discourse_post_event.notifications.before_event_reminder",
        )
      end

      it "correctly identifies ongoing events in different timezones" do
        la_timezone = "America/Los_Angeles"
        la_time = Time.current.in_time_zone(la_timezone) - 30.minutes

        ongoing_event =
          Fabricate(
            :event,
            post: Fabricate(:post),
            reminders: "notification.15.minutes",
            original_starts_at: la_time.to_time,
            original_ends_at: la_time.to_time + 2.hours,
            timezone: la_timezone,
          )

        DiscoursePostEvent::Invitee.create_attendance!(going_user.id, ongoing_event.id, :going)
        going_user.notifications.delete_all

        expect { send_reminder(ongoing_event) }.to change {
          going_user.reload.unread_notifications
        }.by(1)

        notification = going_user.notifications.last
        expect(JSON.parse(notification.data)["message"]).to eq(
          "discourse_post_event.notifications.ongoing_event_reminder",
        )
      end

      it "prevents duplicate reminders for same occurrence" do
        recurring_event.set_next_date

        expect { send_reminder }.to change { going_user.reload.unread_notifications }.by(1)
        expect { send_reminder }.not_to change { going_user.reload.unread_notifications }
      end

      it "handles expired recurring events" do
        DiscoursePostEvent::Invitee.create_attendance!(going_user.id, expired_event.id, :going)

        expect(expired_event.starts_at).to be_nil

        expect { send_reminder(expired_event) }.not_to change {
          going_user.reload.unread_notifications
        }
      end
    end
  end
end
