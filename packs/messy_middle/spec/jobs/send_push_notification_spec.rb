# frozen_string_literal: true

RSpec.describe Jobs::SendPushNotification do
  fab!(:user) { Fabricate(:user) }
  fab!(:subscription) { Fabricate(:push_subscription) }
  let(:payload) { { notification_type: 1, excerpt: "Hello you" } }

  before do
    freeze_time
    SiteSetting.push_notification_time_window_mins = 10
  end

  context "with active online user" do
    it "does not send push notification" do
      user.update!(last_seen_at: 5.minutes.ago)

      PushNotificationPusher.expects(:push).with(user, payload).never

      Jobs::SendPushNotification.new.execute(user_id: user, payload: payload)
    end
  end

  context "with inactive offline user" do
    it "sends push notification" do
      user.update!(last_seen_at: 40.minutes.ago)

      PushNotificationPusher.expects(:push).with(user, payload)

      Jobs::SendPushNotification.new.execute(user_id: user, payload: payload)
    end
  end
end
