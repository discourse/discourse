# frozen_string_literal: true

RSpec.describe Jobs::KickUsersFromChannel do
  fab!(:channel) { Fabricate(:chat_channel) }

  it "publishes the correct MessageBus message" do
    message =
      MessageBus
        .track_publish(ChatPublisher.kick_users_message_bus_channel(channel.id)) do
          described_class.new.execute(channel_id: channel.id, user_ids: [1, 2, 3])
        end
        .first

    expect(message.user_ids).to eq([1, 2, 3])
  end

  it "does nothing if the channel is deleted" do
    channel_id = channel.id
    channel.trash!
    message =
      MessageBus
        .track_publish(ChatPublisher.kick_users_message_bus_channel(channel.id)) do
          described_class.new.execute(channel_id: channel_id, user_ids: [1, 2, 3])
        end
        .first
    expect(message).to be_nil
  end

  it "does nothing if no user_ids are provided" do
    message =
      MessageBus
        .track_publish(ChatPublisher.kick_users_message_bus_channel(channel.id)) do
          described_class.new.execute(channel_id: channel.id)
        end
        .first
    expect(message).to be_nil
  end
end
