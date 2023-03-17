# frozen_string_literal: true

RSpec.describe Chat::StructuredChannelSerializer do
  fab!(:user1) { Fabricate(:user) }
  fab!(:guardian) { Guardian.new(user1) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:channel1) { Fabricate(:category_channel) }
  fab!(:channel2) { Fabricate(:category_channel) }
  fab!(:channel3) do
    Fabricate(:direct_message_channel, users: [user1, user2], with_membership: false)
  end
  fab!(:channel4) do
    Fabricate(:direct_message_channel, users: [user1, user3], with_membership: false)
  end
  fab!(:membership1) do
    Fabricate(:user_chat_channel_membership, user: user1, chat_channel: channel1)
  end
  fab!(:membership2) do
    Fabricate(:user_chat_channel_membership, user: user1, chat_channel: channel2)
  end
  fab!(:membership3) do
    Fabricate(:user_chat_channel_membership_for_dm, user: user1, chat_channel: channel3)
  end
  fab!(:membership4) do
    Fabricate(:user_chat_channel_membership_for_dm, user: user1, chat_channel: channel4)
  end
  fab!(:membership5) do
    Fabricate(:user_chat_channel_membership_for_dm, user: user2, chat_channel: channel3)
  end
  fab!(:membership6) do
    Fabricate(:user_chat_channel_membership_for_dm, user: user3, chat_channel: channel4)
  end

  def fetch_data
    Chat::ChannelFetcher.structured(guardian)
  end

  it "serializes a public channel correctly with membership embedded" do
    expect(
      described_class
        .new(fetch_data, scope: guardian)
        .public_channels
        .find { |channel| channel.id == channel1.id }
        .current_user_membership
        .as_json,
    ).to include(
      "chat_channel_id" => channel1.id,
      "desktop_notification_level" => "mention",
      "following" => true,
      "last_read_message_id" => nil,
      "mobile_notification_level" => "mention",
      "muted" => false,
      "unread_count" => 0,
      "unread_mentions" => 0,
    )
  end

  it "serializes a direct message channel correctly with membership embedded" do
    expect(
      described_class
        .new(fetch_data, scope: guardian)
        .direct_message_channels
        .find { |channel| channel.id == channel3.id }
        .current_user_membership
        .as_json,
    ).to include(
      "chat_channel_id" => channel3.id,
      "desktop_notification_level" => "always",
      "following" => true,
      "last_read_message_id" => nil,
      "mobile_notification_level" => "always",
      "muted" => false,
      "unread_count" => 0,
      "unread_mentions" => 0,
    )
  end

  it "does not include membership details for an anonymous user" do
    expect(
      described_class
        .new(fetch_data, scope: Guardian.new)
        .public_channels
        .find { |channel| channel.id == channel1.id }
        .as_json[
        :current_user_membership
      ],
    ).to eq(nil)
  end

  it "does not include membership if somehow the data is missing" do
    data = fetch_data
    data[:memberships] = data[:memberships].reject do |membership|
      membership.chat_channel_id == channel1.id
    end

    expect(
      described_class
        .new(data, scope: guardian)
        .public_channels
        .find { |channel| channel.id == channel1.id }
        .as_json[
        :current_user_membership
      ],
    ).to eq(nil)
  end
end
