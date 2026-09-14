# frozen_string_literal: true

RSpec.describe Jobs::UserEmail do
  fab!(:user)
  fab!(:post)
  let!(:event) do
    Fabricate(
      :event,
      post: post,
      original_starts_at: 1.hour.from_now,
      reminders: "notification.1.hours",
    )
  end
  let(:reminder) { "notification.1.hours" }
  let(:args) do
    {
      user_id: user.id,
      type: "event_reminder",
      force_respect_seen_recently: true,
      notification_type: "event_reminder",
      notification_data_hash: {
        event_date_id: event.current_event_date.id,
      },
    }
  end

  before do
    freeze_time
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    user.user_option.update!(event_reminder_preference: "email")
    user.update!(last_seen_at: 1.day.ago)
    DiscourseEvents::Events::Invitee.create_attendance!(user.id, event.id, :going)
  end

  describe "#execute" do
    %w[going interested].each do |attendance|
      {
        "notification" => [1, 0],
        "email" => [0, 1],
        "both" => [1, 1],
        "none" => [0, 0],
      }.each do |preference, (notifications, emails)|
        it "delivers #{preference} reminders for #{attendance} attendees" do
          user.user_option.update!(event_reminder_preference: preference)
          event
            .invitees
            .find_by(user: user)
            .update!(status: DiscourseEvents::Events::Invitee.statuses[attendance.to_sym])
          Jobs.run_immediately!

          expect {
            Jobs::DiscoursePostEventSendReminder.new.execute(event_id: event.id, reminder: reminder)
          }.to change {
            user.notifications.where(notification_type: Notification.types[:event_reminder]).count
          }.by(notifications).and change { ActionMailer::Base.deliveries.size }.by(emails)
        end
      end
    end

    it "sends and logs an email without a PM or notification" do
      notification_count = user.notifications.count
      private_topic_count = Topic.private_messages.count
      expect { described_class.new.execute(args) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
      expect(user.notifications.count).to eq(notification_count)
      expect(Topic.private_messages.count).to eq(private_topic_count)
      message = ActionMailer::Base.deliveries.last
      expect(EmailLog.last).to have_attributes(user_id: user.id, email_type: "event_reminder")
      expect(message.to).to eq([user.email])
      expect(message.subject).to include(post.topic.title)
      expect(message.text_part.body.to_s).to include(post.full_url)
    end

    it "logs an activity skip without scheduling catch-up mail" do
      user.update!(last_seen_at: Time.current)
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
      expect(SkippedEmailLog.last).to have_attributes(
        user_id: user.id,
        email_type: "event_reminder",
        reason_type: SkippedEmailLog.reason_types[:user_email_seen_recently],
      )
      expect(described_class.jobs).to be_empty
    end

    it "allows a later reminder after a previous email and reading the post" do
      Fabricate(:email_log, user: user, post: post)
      PostTiming.create!(
        topic_id: post.topic_id,
        post_number: post.post_number,
        user_id: user.id,
        msecs: 1000,
      )
      expect { described_class.new.execute(args) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    it "respects the existing daily email limit" do
      SiteSetting.max_emails_per_day_per_user = 1
      Fabricate(:email_log, user: user)
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
      expect(SkippedEmailLog.last.reason_type).to eq(
        SkippedEmailLog.reason_types[:exceeded_emails_limit],
      )
    end

    it "allows retry after a transient SMTP failure" do
      Mail::TestMailer.any_instance.stubs(:deliver!).raises(Net::SMTPServerBusy.new("busy")).once
      expect { described_class.new.execute(args) }.to raise_error(Net::SMTPServerBusy)
      Mail::TestMailer.any_instance.unstub(:deliver!)
      expect { described_class.new.execute(args) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
      expect(EmailLog.where(user: user, email_type: "event_reminder").count).to eq(1)
    end

    it "honors away-only even with always-email preferences" do
      user.update!(last_seen_at: Time.current)
      user.user_option.update!(
        email_level: UserOption.email_level_types[:always],
        email_messages_level: UserOption.email_level_types[:always],
      )
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "sends at the activity window boundary" do
      user.update!(last_seen_at: SiteSetting.email_time_window_mins.minutes.ago)
      expect { described_class.new.execute(args) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    it "rechecks the preference" do
      user.user_option.update!(event_reminder_preference: "none")
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "rechecks attendance" do
      event
        .invitees
        .find_by(user: user)
        .update!(status: DiscourseEvents::Events::Invitee.statuses[:not_going])
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "rechecks event visibility" do
      post.trash!
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "does not deliver a queued reminder after the event is rescheduled" do
      original_args = args
      event.update!(original_starts_at: 2.days.from_now)
      expect { described_class.new.execute(original_args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "delivers email despite an unread event notification" do
      user.notifications.create!(
        notification_type: Notification.types[:event_reminder],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {}.to_json,
      )
      user.user_option.update!(event_reminder_preference: "both")
      Jobs.run_immediately!
      expect {
        Jobs::DiscoursePostEventSendReminder.new.execute(event_id: event.id, reminder: reminder)
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "respects bounced recipients" do
      user.user_stat.update!(bounce_score: SiteSetting.bounce_score_threshold)
      expect { described_class.new.execute(args) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end
  end
end
