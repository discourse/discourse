require 'rails_helper'

describe PushNotificationController do
  let(:user) { Fabricate(:user) }

  context "logged out" do
    it "should not allow subscribe" do
      post '/push_notifications/subscribe.json', params: {
        username: "test",
        subscription: {
          endpoint: "endpoint",
          keys: {
            p256dh: "256dh",
            auth: "auth"
          }
        },
        send_confirmation: false
      }

      expect(response.status).to eq(403)
    end
  end

  context "logged in" do
    before { sign_in(user) }

    it "should subscribe" do
      post '/push_notifications/subscribe.json', params: {
        username: user.username,
        subscription: {
          endpoint: "endpoint",
          keys: {
            p256dh: "256dh",
            auth: "auth"
          }
        },
        send_confirmation: false
      }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should fix duplicate subscriptions" do
      subscription = {
        endpoint: "endpoint",
        keys: {
          p256dh: "256dh",
          auth: "auth"
        }
      }
      PushSubscription.create user: user, data: subscription.to_json
      post '/push_notifications/subscribe.json', params: {
             username: user.username,
             subscription: subscription,
             send_confirmation: false
           }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should not create duplicate subscriptions" do
      2.times do
        post '/push_notifications/subscribe.json', params: {
           username: user.username,
           subscription: {
             endpoint: "endpoint",
             keys: {
               p256dh: "256dh",
               auth: "auth"
             }
           },
           send_confirmation: false
         }
      end

      expect(response.status).to eq(200)
      expect(user.push_subscriptions.count).to eq(1)
    end

    it "should unsubscribe with existing subscription" do
      sub = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create!(user: user, data: sub.to_json)

      post '/push_notifications/unsubscribe.json', params: {
        username: user.username,
        subscription: sub
      }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to eq([])
    end

    it "should unsubscribe without subscription" do
      post '/push_notifications/unsubscribe.json', params: {
        username: user.username,
        subscription: {
          endpoint: "endpoint",
          keys: {
            p256dh: "256dh",
            auth: "auth"
          }
        }
      }

      expect(response.status).to eq(200)
      expect(user.push_subscriptions).to eq([])
    end
  end

end
