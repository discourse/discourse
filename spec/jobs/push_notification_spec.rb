# frozen_string_literal: true

require "excon"

RSpec.describe Jobs::PushNotification do
  fab!(:user)
  fab!(:post)
  let(:data) do
    {
      "user_id" => user.id,
      "payload" => {
        "notification_type" => 1,
        "post_url" => "/t/#{post.topic_id}/#{post.post_number}",
        "excerpt" => "Hello you",
      },
      "clients" => [[user.id, "http://test.localhost"]],
    }
  end

  before { SiteSetting.push_notification_time_window_mins = 5 }

  context "with valid user" do
    it "does not send push notification when user is online" do
      user.update!(last_seen_at: 1.minute.ago)

      Excon.expects(:post).never

      Jobs::PushNotification.new.execute(data)
    end

    it "sends push notification when user is offline" do
      user.update!(last_seen_at: 10.minutes.ago)

      Excon.expects(:post).once

      Jobs::PushNotification.new.execute(data)
    end
  end

  context "with invalid user" do
    it "does not send push notification" do
      data["user_id"] = -999

      Excon.expects(:post).never

      Jobs::PushNotification.new.execute(data)
    end
  end
end
