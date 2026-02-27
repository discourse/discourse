# frozen_string_literal: true

RSpec.describe Jobs::Chat::KickUsersFromChannel do
  fab!(:channel, :chat_channel)

  it "publishes the correct MessageBus messages to each user" do
    messages =
      MessageBus.track_publish do
        described_class.new.execute(channel_id: channel.id, user_ids: [1, 2, 3])
      end

    kick_messages = messages.select { |m| m.data["type"] == "kick" }
    expect(kick_messages.length).to eq(3)
    expect(kick_messages.map(&:user_ids).flatten).to contain_exactly(1, 2, 3)
  end

  it "does nothing if the channel is deleted" do
    channel_id = channel.id
    channel.trash!
    messages =
      MessageBus.track_publish do
        described_class.new.execute(channel_id: channel_id, user_ids: [1, 2, 3])
      end

    kick_messages = messages.select { |m| m.data["type"] == "kick" }
    expect(kick_messages).to be_empty
  end

  it "does nothing if no user_ids are provided" do
    messages = MessageBus.track_publish { described_class.new.execute(channel_id: channel.id) }

    kick_messages = messages.select { |m| m.data["type"] == "kick" }
    expect(kick_messages).to be_empty
  end
end
