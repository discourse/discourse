# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotificationPusher do

  it "returns badges url by default" do
    expect(PushNotificationPusher.get_badge).to eq("/assets/push-notifications/discourse.png")
  end

  it "returns custom badges url" do
    upload = Fabricate(:upload)
    SiteSetting.push_notifications_icon = upload

    expect(PushNotificationPusher.get_badge)
      .to eq(UrlHelper.absolute(upload.url))
  end

  context "with user" do
    fab!(:user) { Fabricate(:user) }

    def create_subscription
      data = <<~JSON
      {
        "endpoint": "endpoint",
        "keys": {
          "p256dh": "p256dh",
          "auth": "auth"
        }
      }
      JSON
      PushSubscription.create!(user_id: user.id, data: data)
    end

    def execute_push
      PushNotificationPusher.push(user, {
        topic_title: 'Topic',
        username: 'system',
        excerpt: 'description',
        topic_id: 1,
        post_url: "https://example.com/t/1/2",
        notification_type: 1
      })
    end

    it "sends notification in user's locale" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: 'pt_BR')

      Webpush.expects(:payload_send).with do |*args|
        args.to_s.include?("system mencionou")
      end.once

      create_subscription
      execute_push
    end

    it "deletes subscriptions which are erroring regularly" do
      start = freeze_time

      sub = create_subscription

      response = Struct.new(:body, :inspect, :message).new("test", "test", "failed")
      error = Webpush::ResponseError.new(response, "localhost")

      Webpush.expects(:payload_send).raises(error).times(4)

      # 3 failures in more than 24 hours
      3.times do
        execute_push

        freeze_time 1.minute.from_now
      end

      sub.reload
      expect(sub.error_count).to eq(3)
      expect(sub.first_error_at).to eq_time(start)

      freeze_time(2.days.from_now)

      execute_push

      expect(PushSubscription.where(id: sub.id).exists?).to eq(false)
    end

    it "deletes invalid subscriptions during send" do
      missing_endpoint = PushSubscription.create!(user_id: user.id, data:
        { p256dh: "public ECDH key", keys: { auth: "private ECDH key" } }.to_json)

      missing_p256dh = PushSubscription.create!(user_id: user.id, data:
        { endpoint: "endpoint 1", keys: { auth: "private ECDH key" } }.to_json)

      missing_auth = PushSubscription.create!(user_id: user.id, data:
        { endpoint: "endpoint 2", keys: { p256dh: "public ECDH key" } }.to_json)

      valid_subscription = PushSubscription.create!(user_id: user.id, data:
        { endpoint: "endpoint 3", keys: { p256dh: "public ECDH key", auth: "private ECDH key" } }.to_json)

      expect(PushSubscription.where(user_id: user.id)).to contain_exactly(missing_endpoint, missing_p256dh, missing_auth, valid_subscription)
      Webpush.expects(:payload_send).with(has_entries(endpoint: "endpoint 3", p256dh: "public ECDH key", auth: "private ECDH key")).once

      execute_push

      expect(PushSubscription.where(user_id: user.id)).to contain_exactly(valid_subscription)
    end

    it "handles timeouts" do
      Webpush.expects(:payload_send).raises(Net::ReadTimeout.new)
      subscription = create_subscription

      expect { execute_push }.to_not raise_exception

      subscription.reload
      expect(subscription.error_count).to eq(1)
    end
  end
end
