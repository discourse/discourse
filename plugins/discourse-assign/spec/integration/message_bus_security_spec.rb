# frozen_string_literal: true

RSpec.describe "discourse-assign MessageBus security" do
  fab!(:moderator)
  fab!(:recipient) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:private_message_topic, user: moderator, recipient: recipient) }
  fab!(:assignment) { Fabricate(:topic_assignment, topic: topic, assigned_to: moderator) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.unassign_on_close = true
  end

  it "does not expose closing an assigned private message to anonymous MessageBus clients" do
    channel = "/topic/#{topic.id}"
    message_id = MessageBus.last_id(channel)

    sign_in(moderator)
    put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "true" }

    expect(response.status).to eq(200)
    expect(topic.reload).to be_closed

    cookies.to_hash.keys.each { |key| cookies.delete(key) }
    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(recipient)
    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to contain_exactly(
      include("data" => include("reload_topic" => true, "refresh_stream" => true)),
    )
  end

  def topic_reload_messages(channel)
    response.parsed_body.select do |message|
      message["channel"] == channel &&
        message["data"] == { "reload_topic" => true, "refresh_stream" => true }
    end
  end
end
