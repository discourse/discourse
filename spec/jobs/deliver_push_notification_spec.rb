# frozen_string_literal: true

RSpec.describe Jobs::DeliverPushNotification do
  fab!(:user)
  fab!(:post)

  let(:payload) do
    {
      "notification_type" => 1,
      "post_url" => "/t/#{post.topic_id}/#{post.post_number}",
      "excerpt" => "Hello you",
    }
  end

  before do
    freeze_time
    SiteSetting.push_notification_time_window_mins = 5
  end

  describe "time window gate" do
    before { Fabricate(:push_subscription, user: user) }

    it "does not deliver when user is missing" do
      PushNotificationPusher.expects(:push).never
      HubPushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: -999, payload: payload)
    end

    it "does not deliver when user was recently seen" do
      user.update!(last_seen_at: 1.minute.ago)
      PushNotificationPusher.expects(:push).never
      HubPushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "delivers when user is offline" do
      user.update!(last_seen_at: 10.minutes.ago)
      PushNotificationPusher.expects(:push).with(user, payload)
      HubPushNotificationPusher.expects(:push).with(user, payload)
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "delivers when bypass_time_window is true despite user being active" do
      user.update!(last_seen_at: 1.minute.ago)
      PushNotificationPusher.expects(:push).with(user, payload)
      HubPushNotificationPusher.expects(:push).with(user, payload)

      Jobs::DeliverPushNotification.new.execute(
        user_id: user.id,
        bypass_time_window: true,
        payload: payload,
      )
    end
  end

  describe "web push delivery" do
    before { user.update!(last_seen_at: 10.minutes.ago) }

    it "calls PushNotificationPusher when user has push subscriptions" do
      Fabricate(:push_subscription, user: user)
      PushNotificationPusher.expects(:push).with(user, payload).once
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "does not call PushNotificationPusher when user has no push subscriptions" do
      PushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end

  describe "hub push delivery" do
    before { user.update!(last_seen_at: 10.minutes.ago) }

    it "calls HubPushNotificationPusher" do
      HubPushNotificationPusher.expects(:push).with(user, payload).once
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end

  describe "both mechanisms" do
    it "delivers via both pushers for the same user" do
      user.update!(last_seen_at: 10.minutes.ago)
      Fabricate(:push_subscription, user: user)

      PushNotificationPusher.expects(:push).with(user, payload).once
      HubPushNotificationPusher.expects(:push).with(user, payload).once

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end
end
