# frozen_string_literal: true

RSpec.describe MessageBus::Client do
  let(:client) { described_class.new(client_id: "poll-viewer", message_bus: MessageBus) }

  def message(data)
    MessageBus::Message.new(1, 1, "/polls/123", data)
  end

  it "allows invalidation-only messages" do
    expect(client.allowed?(message(post_id: 123))).to eq(true)
  end

  it "rejects legacy content-bearing messages, including retained messages from before deployment" do
    expect(client.allowed?(message(post_id: 123, polls: []))).to eq(false)
    expect(client.allowed?(message("post_id" => 123, "polls" => []))).to eq(false)
  end
end
