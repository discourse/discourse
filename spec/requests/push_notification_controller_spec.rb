# frozen_string_literal: true

RSpec.describe PushNotificationController do
  fab!(:user)

  context "when logged out" do
    it "should not allow subscribe" do
      post "/push_notifications/subscribe.json",
           params: {
             username: "test",
             subscription: {
               endpoint: "endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(403)
    end
  end

  context "when logged in" do
    before { sign_in(user) }

    it "should subscribe" do
      post "/push_notifications/subscribe.json",
           params: {
             username: user.username,
             subscription: {
               endpoint: "endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "rejects a subscription request started by another account" do
      post "/push_notifications/subscribe.json",
           params: {
             user_id: Fabricate(:user).id,
             subscription: {
               endpoint: "stale-account-endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(409)
      expect(user.push_subscriptions).to be_empty
    end

    it "returns a conflict when the session expires during registration" do
      invalidate_session = ->(subscription) do
        user.user_auth_tokens.destroy_all if subscription.user_id == user.id
      end
      PushSubscription.set_callback(:create, :after, invalidate_session)

      post "/push_notifications/subscribe.json",
           params: {
             subscription: {
               endpoint: "stale-endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(409)
      expect(user.push_subscriptions).to be_empty
    ensure
      PushSubscription.skip_callback(:create, :after, invalidate_session) if invalidate_session
    end

    it "should fix duplicate subscriptions" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create user: user, data: subscription.to_json
      post "/push_notifications/subscribe.json",
           params: {
             username: user.username,
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should not create duplicate subscriptions" do
      2.times do
        post "/push_notifications/subscribe.json",
             params: {
               username: user.username,
               subscription: {
                 endpoint: "endpoint",
                 keys: {
                   p256dh: "256dh",
                   auth: "auth",
                 },
               },
               send_confirmation: false,
             }
      end

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should unsubscribe with existing subscription" do
      sub = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create!(user: user, data: sub.to_json)

      post "/push_notifications/unsubscribe.json",
           params: {
             username: user.username,
             subscription: sub,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to eq([])
    end

    it "rejects an unsubscribe request started by another account" do
      sub = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create!(user: user, data: sub.to_json)

      post "/push_notifications/unsubscribe.json",
           params: {
             user_id: Fabricate(:user).id,
             subscription: sub,
           }

      expect(response.status).to eq(409)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should unsubscribe without subscription" do
      post "/push_notifications/unsubscribe.json",
           params: {
             username: user.username,
             subscription: {
               endpoint: "endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to eq([])
    end
  end
end
