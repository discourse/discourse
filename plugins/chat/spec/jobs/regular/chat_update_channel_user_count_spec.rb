# frozen_string_literal: true

RSpec.describe Jobs::ChatUpdateChannelUserCount do
  fab!(:channel) { Fabricate(:category_channel, user_count: 0, user_count_stale: true) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:user4) { Fabricate(:user) }
  fab!(:membership1) do
    Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user1)
  end
  fab!(:membership2) do
    Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user2)
  end
  fab!(:membership3) do
    Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user3)
  end

  it "does nothing if the channel does not exist" do
    channel.destroy
    Chat::Publisher.expects(:publish_chat_channel_metadata).never
    expect(described_class.new.execute(chat_channel_id: channel.id)).to eq(nil)
  end

  it "does nothing if the user count has not been marked stale" do
    channel.update!(user_count_stale: false)
    Chat::Publisher.expects(:publish_chat_channel_metadata).never
    expect(described_class.new.execute(chat_channel_id: channel.id)).to eq(nil)
  end

  it "updates the channel user_count and sets user_count_stale back to false" do
    Chat::Publisher.expects(:publish_chat_channel_metadata).with(channel)
    described_class.new.execute(chat_channel_id: channel.id)
    channel.reload
    expect(channel.user_count).to eq(3)
    expect(channel.user_count_stale).to eq(false)
  end
end
