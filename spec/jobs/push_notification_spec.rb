# frozen_string_literal: true

require "excon"

RSpec.describe Jobs::PushNotification do
  fab!(:user)
  fab!(:user2) { Fabricate(:user) }
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
  let(:data_with_two_clients) do
    {
      "user_id" => user.id,
      "payload" => {
        "notification_type" => 1,
        "post_url" => "/t/#{post.topic_id}/#{post.post_number}",
        "excerpt" => "Hello you",
      },
      "clients" => [[user2.id, "https://test2.localhost"], [user.id, "http://test.localhost"]],
    }
  end

  let!(:request) do
    stub_request(:post, "http://test.localhost").with(
      body: {
        secret_key: SiteSetting.push_api_secret_key,
        url: "http://test.localhost",
        title: "Discourse",
        description: "",
        notifications: [
          {
            notification_type: 1,
            excerpt: "Hello you",
            url: "http://test.localhost/t/#{post.topic_id}/#{post.post_number}",
            client_id: user.id,
          },
        ],
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: "", headers: {})
  end

  let!(:bad_request) do
    stub_request(:post, "https://test2.localhost/").with(
      body: {
        secret_key: SiteSetting.push_api_secret_key,
        url: "http://test.localhost",
        title: "Discourse",
        description: "",
        notifications: [
          {
            notification_type: 1,
            excerpt: "Hello you",
            url: "http://test.localhost/t/#{post.topic_id}/#{post.post_number}",
            client_id: user2.id,
          },
        ],
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    ).to_return(status: 404, body: "", headers: {})
  end

  before { SiteSetting.push_notification_time_window_mins = 5 }

  context "with valid user" do
    it "does not send push notification when user is online" do
      user.update!(last_seen_at: 1.minute.ago)

      Jobs::PushNotification.new.execute(data)

      expect(request).not_to have_been_requested
    end

    it "sends push notification when user is offline" do
      user.update!(last_seen_at: 10.minutes.ago)

      Jobs::PushNotification.new.execute(data)

      expect(request).to have_been_requested.once
    end
  end

  context "with invalid user" do
    it "does not send push notification" do
      data["user_id"] = -999

      Jobs::PushNotification.new.execute(data)

      expect(request).not_to have_been_requested
    end
  end

  context "with two clients" do
    it "sends push notifications to both clients" do
      user.update!(last_seen_at: 10.minutes.ago)
      user2.update!(last_seen_at: 10.minutes.ago)

      Jobs::PushNotification.new.execute(data_with_two_clients)

      expect(request).to have_been_requested
      expect(bad_request).to have_been_requested
    end
  end
end
