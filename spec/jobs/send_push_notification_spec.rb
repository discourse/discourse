# frozen_string_literal: true

RSpec.describe Jobs::SendPushNotification do
  fab!(:user)
  fab!(:subscription) { Fabricate(:push_subscription) }
  let(:payload) { { notification_type: 1, excerpt: "Hello you" } }

  before do
    freeze_time
    SiteSetting.push_notification_time_window_mins = 10
  end

  context "with valid user" do
    it "does not send push notification when user is online" do
      user.update!(last_seen_at: 2.minutes.ago)

      PushNotificationPusher.expects(:push).with(user, payload).never

      Jobs::SendPushNotification.new.execute(user_id: user, payload: payload)
    end

    it "bypasses the online window when bypass_time_window is passed in" do
      user.update!(last_seen_at: 2.minutes.ago)

      PushNotificationPusher.expects(:push).with(user, payload)

      Jobs::SendPushNotification.new.execute(
        user_id: user,
        bypass_time_window: true,
        payload: payload,
      )
    end

    it "sends push notification when user is offline" do
      user.update!(last_seen_at: 20.minutes.ago)

      PushNotificationPusher.expects(:push).with(user, payload)

      Jobs::SendPushNotification.new.execute(user_id: user, payload: payload)
    end
  end

  context "with invalid user" do
    it "does not send push notification" do
      PushNotificationPusher.expects(:push).with(user, payload).never

      Jobs::SendPushNotification.new.execute(user_id: -999, payload: payload)
    end
  end
end
