# frozen_string_literal: true

RSpec.describe Notification::Action::BulkCreate do
  describe ".call" do
    subject(:action) { described_class.call(records:, **options) }

    fab!(:user1, :user) { Fabricate(:user, last_seen_at: 1.hour.ago) }
    fab!(:user2, :user) { Fabricate(:user, last_seen_at: 1.hour.ago) }

    let(:options) { {} }

    context "when records is empty" do
      let(:records) { [] }

      it "returns an empty array" do
        expect(action).to eq([])
      end

      it "does not create any notifications" do
        expect { action }.not_to change { Notification.count }
      end
    end

    context "when records is nil" do
      let(:records) { nil }

      it "returns an empty array" do
        expect(action).to eq([])
      end
    end

    context "with a single notification" do
      let(:records) do
        [
          {
            user_id: user1.id,
            notification_type: Notification.types[:custom],
            data: { message: "test" }.to_json,
          },
        ]
      end

      it "creates the notification" do
        expect { action }.to change { Notification.count }.by(1)
      end

      it "returns the notification ids" do
        notification_ids = action
        expect(notification_ids.length).to eq(1)
        expect(Notification.find(notification_ids.first)).to be_present
      end

      it "sets the correct notification attributes" do
        notification_ids = action
        notification = Notification.find(notification_ids.first)

        expect(notification.user_id).to eq(user1.id)
        expect(notification.notification_type).to eq(Notification.types[:custom])
        expect(notification.data_hash).to eq({ "message" => "test" })
        expect(notification.read).to eq(false)
      end

      it "publishes notification state to the user" do
        messages = MessageBus.track_publish("/notification/#{user1.id}") { action }

        expect(messages.length).to eq(1)
      end

      it "triggers the notification_created event" do
        events = DiscourseEvent.track_events(:notification_created) { action }

        expect(events.length).to eq(1)
        expect(events.first[:params].first.user_id).to eq(user1.id)
      end

      it "processes email via NotificationEmailer" do
        NotificationEmailer.expects(:process_notification).once
        action
      end
    end

    context "with multiple notifications for different users" do
      let(:records) do
        [
          {
            user_id: user1.id,
            notification_type: Notification.types[:custom],
            data: { message: "test1" }.to_json,
          },
          {
            user_id: user2.id,
            notification_type: Notification.types[:custom],
            data: { message: "test2" }.to_json,
          },
        ]
      end

      it "creates all notifications" do
        expect { action }.to change { Notification.count }.by(2)
      end

      it "returns all notification ids" do
        notification_ids = action
        expect(notification_ids.length).to eq(2)
      end

      it "publishes notification state to each user" do
        messages1 = MessageBus.track_publish("/notification/#{user1.id}") { action }
        expect(messages1.length).to eq(1)
      end

      it "triggers the notification_created event for each notification" do
        events = DiscourseEvent.track_events(:notification_created) { action }

        expect(events.length).to eq(2)
        expect(events.map { |e| e[:params].first.user_id }).to contain_exactly(user1.id, user2.id)
      end
    end

    context "with high_priority notification type" do
      let(:records) do
        [
          {
            user_id: user1.id,
            notification_type: Notification.types[:private_message],
            data: {}.to_json,
          },
        ]
      end

      it "sets high_priority to true based on notification type" do
        notification_ids = action
        notification = Notification.find(notification_ids.first)

        expect(notification.high_priority).to eq(true)
      end
    end

    context "with explicit high_priority option" do
      let(:records) do
        [
          {
            user_id: user1.id,
            notification_type: Notification.types[:custom],
            data: {}.to_json,
            high_priority: true,
          },
        ]
      end

      it "respects the explicit high_priority value" do
        notification_ids = action
        notification = Notification.find(notification_ids.first)

        expect(notification.high_priority).to eq(true)
      end
    end

    context "when user is in do not disturb mode" do
      before do
        Fabricate(
          :do_not_disturb_timing,
          user: user1,
          starts_at: 1.hour.ago,
          ends_at: 1.hour.from_now,
        )
      end

      let(:records) do
        [{ user_id: user1.id, notification_type: Notification.types[:custom], data: {}.to_json }]
      end

      it "creates a shelved notification instead of processing email" do
        expect { action }.to change { ShelvedNotification.count }.by(1)
      end

      it "does not process email via NotificationEmailer" do
        NotificationEmailer.expects(:process_notification).never
        action
      end
    end

    context "with skip_send_email option" do
      let(:options) { { skip_send_email: true } }
      let(:records) do
        [{ user_id: user1.id, notification_type: Notification.types[:custom], data: {}.to_json }]
      end

      it "does not process email via NotificationEmailer" do
        NotificationEmailer.expects(:process_notification).never
        action
      end

      it "does not create shelved notifications" do
        expect { action }.not_to change { ShelvedNotification.count }
      end

      it "still triggers the notification_created event" do
        events = DiscourseEvent.track_events(:notification_created) { action }

        expect(events.length).to eq(1)
      end
    end

    context "with optional attributes" do
      fab!(:topic)

      let(:records) do
        [
          {
            user_id: user1.id,
            notification_type: Notification.types[:replied],
            data: {}.to_json,
            topic_id: topic.id,
            post_number: 3,
          },
        ]
      end

      it "sets topic_id and post_number" do
        notification_ids = action
        notification = Notification.find(notification_ids.first)

        expect(notification.topic_id).to eq(topic.id)
        expect(notification.post_number).to eq(3)
      end
    end
  end
end
