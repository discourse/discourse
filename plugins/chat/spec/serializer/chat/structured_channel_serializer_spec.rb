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
      "notification_level" => "mention",
      "following" => true,
      "last_read_message_id" => nil,
      "muted" => false,
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
      "notification_level" => "always",
      "following" => true,
      "last_read_message_id" => nil,
      "muted" => false,
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

  describe "#meta" do
    context "when user is anonymous" do
      it "does not query MessageBus for the user_tracking_state_message_bus_channel last_id" do
        Chat::Publisher.expects(:user_tracking_state_message_bus_channel).never
        json = described_class.new(fetch_data, scope: Guardian.new).as_json
        expect(
          json.dig(:structured_channel, :meta, :message_bus_last_ids).key?(:user_tracking_state),
        ).to eq(false)
      end
    end

    context "when user is not anonymous" do
      it "has the required message_bus_last_ids" do
        expect(
          described_class
            .new(fetch_data, scope: guardian)
            .as_json
            .dig(:structured_channel, :meta, :message_bus_last_ids)
            .keys,
        ).to eq(
          %i[
            channel_metadata
            channel_edits
            channel_status
            new_channel
            archive_status
            user_tracking_state
          ],
        )
      end

      it "calls MessageBus.last_ids with all the required channels for each public and DM chat chat channel" do
        MessageBus
          .expects(:last_ids)
          .with do |*args|
            [
              Chat::Publisher::CHANNEL_METADATA_MESSAGE_BUS_CHANNEL,
              Chat::Publisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL,
              Chat::Publisher::CHANNEL_STATUS_MESSAGE_BUS_CHANNEL,
              Chat::Publisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL,
              Chat::Publisher::CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL,
              Chat::Publisher.user_tracking_state_message_bus_channel(user1.id),
              Chat::Publisher.new_messages_message_bus_channel(channel1.id),
              Chat::Publisher.new_mentions_message_bus_channel(channel1.id),
              Chat::Publisher.kick_users_message_bus_channel(channel1.id),
              Chat::Publisher.root_message_bus_channel(channel1.id),
              Chat::Publisher.new_messages_message_bus_channel(channel2.id),
              Chat::Publisher.new_mentions_message_bus_channel(channel2.id),
              Chat::Publisher.kick_users_message_bus_channel(channel2.id),
              Chat::Publisher.root_message_bus_channel(channel2.id),
              Chat::Publisher.new_messages_message_bus_channel(channel3.id),
              Chat::Publisher.new_mentions_message_bus_channel(channel3.id),
              Chat::Publisher.root_message_bus_channel(channel3.id),
              Chat::Publisher.new_messages_message_bus_channel(channel4.id),
              Chat::Publisher.new_mentions_message_bus_channel(channel4.id),
              Chat::Publisher.root_message_bus_channel(channel4.id),
            ].to_set == args.to_set
          end
          .returns({})

        described_class.new(fetch_data, scope: guardian).as_json
      end

      it "passes down the required message_bus ids for category channels to Chat::ChannelSerializer" do
        data = fetch_data
        Chat::ChannelSerializer.expects(:new).at_least_once
        Chat::ChannelSerializer
          .expects(:new)
          .with(
            channel1,
            root: nil,
            scope: guardian,
            membership: membership1,
            new_messages_message_bus_last_id: 0,
            new_mentions_message_bus_last_id: 0,
            kick_message_bus_last_id: 0,
            channel_message_bus_last_id: 0,
            can_join_chat_channel: true,
            post_allowed_category_ids: nil,
          )
          .once
        described_class.new(data, scope: guardian).as_json
      end

      it "passes down the required message_bus ids for direct message channels to Chat::ChannelSerializer" do
        data = fetch_data
        Chat::ChannelSerializer.expects(:new).at_least_once
        Chat::ChannelSerializer
          .expects(:new)
          .with(
            channel3,
            root: nil,
            scope: guardian,
            membership: membership3,
            new_messages_message_bus_last_id: 0,
            new_mentions_message_bus_last_id: 0,
            channel_message_bus_last_id: 0,
          )
          .once
        described_class.new(data, scope: guardian).as_json
      end
    end
  end
end
