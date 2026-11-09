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

    it "rejects missing, blank, and non-string endpoints without storing subscriptions" do
      [nil, "", " ", 1, false, true, [], {}].each do |endpoint|
        post "/push_notifications/subscribe.json",
             params: {
               subscription: {
                 endpoint: endpoint,
                 keys: {
                   p256dh: "key",
                   auth: "auth",
                 },
               },
               send_confirmation: false,
             },
             as: :json

        expect(response.status).to eq(400)
        expect(user.push_subscriptions).to be_empty
      end

      post "/push_notifications/subscribe.json",
           params: {
             subscription: {
               keys: {
                 p256dh: "key",
                 auth: "auth",
               },
             },
           },
           as: :json

      expect(response.status).to eq(400)
      expect(user.push_subscriptions).to be_empty
    end

    it "rejects malformed unsubscribe endpoints without deleting valid subscriptions" do
      existing = Fabricate(:push_subscription, user: user)
      [nil, "", " ", 1, false, true, [], {}].each do |endpoint|
        post "/push_notifications/unsubscribe.json",
             params: {
               subscription: {
                 endpoint: endpoint,
                 keys: {
                   p256dh: "key",
                   auth: "auth",
                 },
               },
             },
             as: :json

        expect(response.status).to eq(400)
        expect(user.push_subscriptions).to contain_exactly(existing)
      end
    end

    it "rejects an endpoint over the size limit" do
      endpoint = "https://push.example/".ljust(PushSubscription::MAX_ENDPOINT_BYTES + 1, "a")
      post "/push_notifications/subscribe.json",
           params: {
             subscription: {
               endpoint: endpoint,
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(400)
      expect(user.push_subscriptions).to be_empty
    end

    it "accepts an endpoint at the size limit" do
      endpoint = "https://push.example/".ljust(PushSubscription::MAX_ENDPOINT_BYTES, "a")
      post "/push_notifications/subscribe.json",
           params: {
             subscription: {
               endpoint: endpoint,
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.sole.parsed_data["endpoint"]).to eq(endpoint)
    end

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
      expect(other_user.push_subscriptions.reload).to be_empty
    end

    it "updates rotated keys on the user's existing subscription" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "old-key", auth: "old-auth" } }
      existing = PushSubscription.create!(user: user, data: subscription.to_json)
      subscription[:keys] = { auth: "new-auth", p256dh: "new-key" }

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: false,
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to contain_exactly(existing)
      expect(existing.reload.parsed_data).to eq(subscription.deep_stringify_keys)
    end

    it "sends the confirmation for an endpoint the user already has" do
      subscription = {
        endpoint: "https://fcm.googleapis.com/fcm/send/existing",
        keys: {
          p256dh: "256dh",
          auth: "auth",
        },
      }
      existing = PushSubscription.create!(user: user, data: subscription.to_json)
      PushNotificationPusher.expects(:send_notification).with(user, existing, anything)

      post "/push_notifications/subscribe.json",
           params: {
             subscription: subscription,
             send_confirmation: "true",
           }

      expect(response.status).to eq(200)
    end

    it "rate limits registering new subscriptions" do
      RateLimiter.enable

      (PushNotificationPusher::SUBSCRIBE_RATE_LIMIT_PER_HOUR + 1).times do |index|
        post "/push_notifications/subscribe.json",
             params: {
               subscription: {
                 endpoint: "https://fcm.googleapis.com/fcm/send/#{index}",
                 keys: {
                   p256dh: "256dh",
                   auth: "auth",
                 },
               },
               send_confirmation: false,
             }
      end

      expect(response.status).to eq(429)
      expect(user.push_subscriptions.count).to eq(
        PushNotificationPusher::SUBSCRIBE_RATE_LIMIT_PER_HOUR,
      )
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

    it "unsubscribes by endpoint when the stored keys differ" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "old-key", auth: "old-auth" } }
      PushSubscription.create!(user: user, data: subscription.to_json)
      subscription[:keys] = { p256dh: "new-key", auth: "new-auth" }

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
      expect(other_user.push_subscriptions.reload).to contain_exactly(existing)
    end
  end
end
