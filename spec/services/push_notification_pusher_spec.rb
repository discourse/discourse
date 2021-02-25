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

end
