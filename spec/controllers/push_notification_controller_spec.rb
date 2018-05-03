require 'rails_helper'

describe PushNotificationController do

  context "logged out" do
    it "should not allow subscribe" do
      get :subscribe, params: { username: "test", subscription: { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }, send_confirmation: false, format: :json }, format: :json
      expect(response).not_to be_success
      json = JSON.parse(response.body)

      expect(response).not_to be_success
    end
  end

  context "logged in" do

    let(:user) { log_in }

    it "should subscribe" do
      get :subscribe, params: { username: user.username, subscription: { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }, send_confirmation: false, format: :json }, format: :json
      expect(response).to be_success
      json = JSON.parse(response.body)

      expect(response).to be_success
    end

    it "should unsubscribe with existing subscription" do
      sub = { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }
      PushSubscription.create(user: user, data: sub.to_json)

      get :unsubscribe, params: { username: user.username, subscription: sub, format: :json }, format: :json
      expect(response).to be_success
      json = JSON.parse(response.body)

      expect(response).to be_success
    end

    it "should unsubscribe without subscription" do

      get :unsubscribe, params: { username: user.username, subscription: { endpoint: "endpoint", keys: { p256dh: "256dh", auth: "auth" } }, format: :json }, format: :json
      expect(response).to be_success
      json = JSON.parse(response.body)

      expect(response).to be_success
    end
  end

end
