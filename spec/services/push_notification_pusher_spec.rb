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

  it "sends notification in user's locale" do
    SiteSetting.allow_user_locale = true
    user = Fabricate(:user, locale: 'pt_BR')
    PushSubscription.create!(user_id: user.id, data: "{\"endpoint\": \"endpoint\"}")

    PushNotificationPusher.expects(:send_notification).with(user, { "endpoint" => "endpoint" }, {
      title: "system mencionou você em \"Topic\" - Discourse",
      body: "description",
      badge: "/assets/push-notifications/discourse.png",
      icon: "/assets/push-notifications/mentioned.png",
      tag: "test.localhost-1",
      base_url: "http://test.localhost",
      url: "https://example.com/t/1/2",
      hide_when_active: true
    }).once

    PushNotificationPusher.push(user, {
      topic_title: 'Topic',
      username: 'system',
      excerpt: 'description',
      topic_id: 1,
      post_url: "https://example.com/t/1/2",
      notification_type: 1
    })
  end

  it "deletes invalid subscriptions during send" do
    user = Fabricate(:walter_white)

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

    PushNotificationPusher.push(user, {
      topic_title: 'Topic',
      username: 'system',
      excerpt: 'description',
      topic_id: 1,
      post_url: "https://example.com/t/1/2",
      notification_type: 1
    })

    expect(PushSubscription.where(user_id: user.id)).to contain_exactly(valid_subscription)
  end
end
