# frozen_string_literal: true

RSpec.describe PushNotificationController do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

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

    it "registers the shadow, not the master, when browsing anonymously" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)

      post "/push_notifications/subscribe.json",
           params: {
             subscription: {
               endpoint: "endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
           }

      expect(response.status).to eq(200)
      expect(user.shadow_user.push_subscriptions.count).to eq(1)
      expect(user.push_subscriptions).to be_empty
    end

    it "does not register new push subscriptions using an external polling credential" do
      token = user.user_auth_tokens.sole
      key = Auth::DefaultCurrentUserProvider.store_shared_session_key(token, user)
      reset!
      headers = { "HTTP_X_SHARED_SESSION_KEY" => key }
      get "/session/current.json", headers: headers
      expect(response.parsed_body.dig("current_user", "id")).to eq(user.id)

      post "/push_notifications/subscribe.json",
           headers: headers,
           params: {
             subscription: {
               endpoint: "endpoint",
               keys: {
                 p256dh: "256dh",
                 auth: "auth",
               },
             },
           }

      expect(response.status).to eq(403)
      expect(user.push_subscriptions).to be_empty
    end

    it "repairs duplicate subscriptions" do
      subscription = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      2.times { PushSubscription.create!(user: user, data: subscription.to_json) }
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
  end
end
