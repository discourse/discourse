# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ChatStreamer do
  fab!(:admin)
  fab!(:channel, :category_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: admin) }

  it "clears typing when a reply contains only an approval request" do
    guardian = admin.guardian
    presence = PresenceChannel.new("/chat-reply/#{channel.id}")
    streamer =
      described_class.new(
        message: message,
        channel: channel,
        guardian: guardian,
        thread_id: nil,
        in_reply_to_id: message.id,
        force_thread: true,
      )

    expect(presence.count).to eq(1)
    expect { streamer.done }.to change { presence.count }.from(1).to(0)
    expect(streamer.reply).to be_nil
    expect { streamer.done }.not_to change { presence.count }
  end
end
