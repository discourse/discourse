# frozen_string_literal: true

RSpec.describe PushNotificationController do
  fab!(:user)

  context "when logged out" do
    it "does not allow subscribing" do
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

    it "subscribes the user" do
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

    it "repairs duplicate subscriptions" do
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

    it "does not create duplicate subscriptions" do
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

    it "moves an endpoint registered by another user to the current user" do
      other_user = Fabricate(:user)
      subscription = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create!(user: other_user, data: subscription.to_json)

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
      expect(other_user.push_subscriptions).to be_empty
    end

    it "transfers an endpoint when its keys use equivalent base64 encodings" do
      other_user = Fabricate(:user)
      public_key = OpenSSL::PKey::EC.generate("prime256v1").public_key.to_bn.to_s(2)
      subscription = {
        endpoint: "https://push.example/subscription",
        keys: {
          p256dh: Base64.urlsafe_encode64(public_key, padding: false),
          auth: Base64.urlsafe_encode64("a" * 16, padding: false),
        },
      }
      existing = PushSubscription.create!(user: other_user, data: subscription.to_json)
      subscription[:keys].transform_values! do |key|
        Base64.urlsafe_encode64(Base64.urlsafe_decode64(key))
      end

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
      expect(other_user.push_subscriptions).to be_empty
      expect(existing.reload.parsed_data).to eq(subscription.deep_stringify_keys)

      WebPush.expects(:payload_send).never
      PushNotificationPusher.push(other_user, notification_type: Notification.types[:mentioned])
    end

    it "updates rotated keys without creating another owner for the endpoint" do
      other_user = Fabricate(:user)
      subscription = { endpoint: "endpoint", keys: { p256dh: "old-key", auth: "old-auth" } }
      existing = PushSubscription.create!(user: other_user, data: subscription.to_json)
      subscription[:keys] = { auth: "new-auth", p256dh: "new-key" }

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to contain_exactly(existing)
      expect(other_user.push_subscriptions).to be_empty
      expect(existing.reload.parsed_data).to eq(subscription.deep_stringify_keys)
    end

    it "transfers equivalent endpoint URLs to a single owner" do
      other_user = Fabricate(:user)
      subscription = {
        endpoint: "https://push.example/subscription",
        keys: {
          p256dh: "key",
          auth: "auth",
        },
      }
      existing = PushSubscription.create!(user: other_user, data: subscription.to_json)
      subscription[:endpoint] = "https://PUSH.example:443/a/../%73ubscription#ignored"

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to contain_exactly(existing)
      expect(other_user.push_subscriptions).to be_empty
      expect(existing.reload.parsed_data["endpoint"]).to eq("https://push.example/subscription")

      post "/push_notifications/unsubscribe.json", params: { subscription: subscription }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.reload).to be_empty
    end

    it "sends the confirmation for an endpoint the user already has" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      existing = PushSubscription.create!(user: user, data: subscription.to_json)
      PushNotificationPusher.expects(:send_notification).with(user, existing, anything)

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: "true",
           }

      expect(response.status).to eq(200)
    end

    it "unsubscribes an existing subscription" do
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

    it "handles unsubscribing without a subscription" do
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

    it "unsubscribes by endpoint even when the stored key representation differs" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "key", auth: "YQ" } }
      PushSubscription.create!(user: user, data: subscription.to_json)
      subscription[:keys][:auth] = "YQ=="

      post "/push_notifications/unsubscribe.json", params: { subscription: subscription }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to be_empty
    end

    it "preserves the new owner's subscription when the previous owner unsubscribes" do
      other_user = Fabricate(:user)
      subscription = { endpoint: "endpoint", keys: { p256dh: "key", auth: "auth" } }
      existing = PushSubscription.create!(user: other_user, data: subscription.to_json)

      post "/push_notifications/unsubscribe.json", params: { subscription: subscription }

      expect(response.status).to eq(200)
      expect(other_user.push_subscriptions).to contain_exactly(existing)
    end
  end
end
