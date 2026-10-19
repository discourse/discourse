# frozen_string_literal: true

describe Chat::McpTools::ListMessages do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:first_message) do
    Fabricate(:chat_message, chat_channel: channel, user:, message: "First message")
  end
  fab!(:second_message) do
    Fabricate(:chat_message, chat_channel: channel, user:, message: "Second message")
  end

  let(:request_context) do
    instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
  end

  before do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(user)
  end

  it "returns the compatible bounded chat message contract" do
    result =
      described_class.call(
        arguments: {
          "channel_id" => channel.id,
          "page_size" => 1,
          "target_message_id" => second_message.id,
          "direction" => "past",
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(result[:channel_id]).to eq(channel.id)
    expect(result[:messages].sole).to include(
      id: first_message.id,
      message: "First message",
      edited: false,
      in_reply_to_id: nil,
    )
    expect(result[:meta]).to include(
      returned: 1,
      can_load_more_past: true,
      can_load_more_future: nil,
      target_message_id: second_message.id,
    )
  end

  it "does not expose a channel the user cannot view" do
    private_channel = Fabricate(:private_category_channel)

    expect do
      described_class.call(arguments: { "channel_id" => private_channel.id }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError)
  end
end
