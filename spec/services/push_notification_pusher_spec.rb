require 'rails_helper'

RSpec.describe PushNotificationPusher do

  it "returns badges url by default" do
    expect(PushNotificationPusher.get_badge).to eq("/assets/push-notifications/discourse.png")
  end

  it "returns custom badges url" do
    SiteSetting.push_notifications_icon_url = "/test.png"
    expect(PushNotificationPusher.get_badge).to eq("/test.png")
  end

end
