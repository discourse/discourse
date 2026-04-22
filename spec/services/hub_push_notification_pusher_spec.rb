# frozen_string_literal: true

RSpec.describe HubPushNotificationPusher do
  fab!(:user)
  fab!(:post)

  let(:payload) do
    {
      "notification_type" => 1,
      "post_url" => "/t/#{post.topic_id}/#{post.post_number}",
      "excerpt" => "Hello you",
    }
  end

  def setup_hub_client(user, push_url: "https://hub.example.com/push", client_id: nil)
    client =
      Fabricate(
        :user_api_key_client,
        client_id: client_id || SecureRandom.hex,
        application_name: "TestApp",
      )
    Fabricate(
      :user_api_key,
      user: user,
      scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
      push_url: push_url,
      user_api_key_client_id: client.id,
    )
  end

  before { SiteSetting.allowed_user_api_push_urls = "https://hub.example.com/push" }

  it "does nothing when no hub clients exist" do
    stub = stub_request(:post, "https://hub.example.com/push").to_return(status: 200)

    HubPushNotificationPusher.push(user, payload)
    expect(stub).not_to have_been_requested
  end

  it "sends HTTP POST to push_url" do
    setup_hub_client(user)

    stub =
      stub_request(:post, "https://hub.example.com/push").with(
        headers: {
          "Content-Type" => "application/json",
        },
      ).to_return(status: 200)

    HubPushNotificationPusher.push(user, payload)
    expect(stub).to have_been_requested.once
  end

  it "includes correct payload structure" do
    setup_hub_client(user)
    body = nil

    stub_request(:post, "https://hub.example.com/push").to_return do |request|
      body = JSON.parse(request.body)
      { status: 200 }
    end

    HubPushNotificationPusher.push(user, payload)

    expect(body["secret_key"]).to eq(SiteSetting.push_api_secret_key)
    expect(body["url"]).to eq(Discourse.base_url)
    expect(body["title"]).to eq(SiteSetting.title)
    expect(body["notifications"]).to be_present
    expect(body["notifications"].first["url"]).to include("/t/#{post.topic_id}/#{post.post_number}")
    expect(body["notifications"].first).not_to have_key("post_url")
  end

  it "groups notifications by push_url" do
    SiteSetting.allowed_user_api_push_urls =
      "https://hub1.example.com/push|https://hub2.example.com/push"

    setup_hub_client(user, push_url: "https://hub1.example.com/push", client_id: "client1")
    setup_hub_client(user, push_url: "https://hub1.example.com/push", client_id: "client2")
    setup_hub_client(user, push_url: "https://hub2.example.com/push", client_id: "client3")

    stub1 = stub_request(:post, "https://hub1.example.com/push").to_return(status: 200)
    stub2 = stub_request(:post, "https://hub2.example.com/push").to_return(status: 200)

    HubPushNotificationPusher.push(user, payload)

    expect(stub1).to have_been_requested.once
    expect(stub2).to have_been_requested.once
  end

  it "does not mutate the original payload" do
    setup_hub_client(user)
    stub_request(:post, "https://hub.example.com/push").to_return(status: 200)

    original_payload = payload.deep_dup
    HubPushNotificationPusher.push(user, payload)

    expect(payload).to eq(original_payload)
  end
end
