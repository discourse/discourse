# frozen_string_literal: true

describe Chat::ChannelSerializer do
  subject(:serializer) { described_class.new(chat_channel, scope: guardian, root: nil) }

  fab!(:user)
  fab!(:admin)
  fab!(:chat_channel)

  let(:guardian_user) { user }
  let(:guardian) { Guardian.new(guardian_user) }

  describe "archive status" do
    context "when user is not staff" do
      let(:guardian_user) { user }

      it "does not return any sort of archive status" do
        expect(serializer.as_json.key?(:archive_completed)).to eq(false)
      end

      it "includes allow_channel_wide_mentions" do
        expect(serializer.as_json.key?(:allow_channel_wide_mentions)).to eq(true)
      end
    end

    context "when user is staff" do
      let(:guardian_user) { admin }

      it "includes the archive status if the channel is archived and the archive record exists" do
        expect(serializer.as_json.key?(:archive_completed)).to eq(false)

        chat_channel.update!(status: Chat::Channel.statuses[:archived])
        expect(serializer.as_json.key?(:archive_completed)).to eq(false)

        Chat::ChannelArchive.create!(
          chat_channel: chat_channel,
          archived_by: admin,
          destination_topic_title: "This will be the archive topic",
          total_messages: 10,
        )
        chat_channel.reload
        expect(serializer.as_json.key?(:archive_completed)).to eq(true)
      end

      it "includes allow_channel_wide_mentions" do
        expect(serializer.as_json.key?(:allow_channel_wide_mentions)).to eq(true)
      end
    end
  end

  describe "#meta" do
    context "for category channels" do
      fab!(:chat_channel)

      it "has the required message_bus_last_ids keys and calls MessageBus" do
        MessageBus.expects(:last_id).with(Chat::Publisher.root_message_bus_channel(chat_channel.id))
        MessageBus.expects(:last_id).with(
          Chat::Publisher.new_messages_message_bus_channel(chat_channel.id),
        )
        MessageBus.expects(:last_id).with(
          Chat::Publisher.new_mentions_message_bus_channel(chat_channel.id),
        )
        MessageBus.expects(:last_id).with(
          Chat::Publisher.kick_users_message_bus_channel(chat_channel.id),
        )
        expect(serializer.as_json.dig(:meta, :message_bus_last_ids).keys).to eq(
          %i[channel_message_bus_last_id new_messages new_mentions kick],
        )
      end

      it "gets the kick_message_bus_last_id" do
        MessageBus.expects(:last_id).at_least_once
        MessageBus.expects(:last_id).with(
          Chat::Publisher.kick_users_message_bus_channel(chat_channel.id),
        )
        expect(serializer.as_json[:meta][:message_bus_last_ids].key?(:kick)).to eq(true)
      end

      it "does not call MessageBus for last_id if all the last IDs are already passed in" do
        MessageBus.expects(:last_id).never
        described_class.new(
          chat_channel,
          scope: guardian,
          root: nil,
          channel_message_bus_last_id: 1,
          new_messages_message_bus_last_id: 1,
          new_mentions_message_bus_last_id: 1,
          kick_message_bus_last_id: 1,
        ).as_json
      end
    end

    context "for direct message channels" do
      fab!(:chat_channel, :direct_message_channel)

      it "has the required message_bus_last_ids keys and calls MessageBus" do
        MessageBus.expects(:last_id).with(Chat::Publisher.root_message_bus_channel(chat_channel.id))
        MessageBus.expects(:last_id).with(
          Chat::Publisher.new_messages_message_bus_channel(chat_channel.id),
        )
        MessageBus.expects(:last_id).with(
          Chat::Publisher.new_mentions_message_bus_channel(chat_channel.id),
        )
        expect(serializer.as_json.dig(:meta, :message_bus_last_ids).keys).to eq(
          %i[channel_message_bus_last_id new_messages new_mentions],
        )
      end

      it "does not get the kick_message_bus_last_id" do
        MessageBus.expects(:last_id).at_least_once
        MessageBus
          .expects(:last_id)
          .with(Chat::Publisher.kick_users_message_bus_channel(chat_channel.id))
          .never
        expect(serializer.as_json[:meta][:message_bus_last_ids].key?(:kick)).to eq(false)
      end
    end
  end

  it "has a unicode_title" do
    chat_channel.update!(name: ":cat: Cats")

    expect(serializer.as_json[:unicode_title]).to eq("🐈 Cats")
  end

  describe "#last_message" do
    fab!(:last_message) { Fabricate(:chat_message, chat_channel: chat_channel) }

    before { chat_channel.update!(last_message: last_message) }

    context "when the user can preview the channel" do
      let(:guardian_user) { admin }

      it "includes the last_message" do
        expect(serializer.as_json[:last_message]).to be_present
        expect(serializer.as_json[:last_message][:id]).to eq(last_message.id)
      end
    end

    context "when the user cannot preview the channel" do
      fab!(:private_channel, :private_category_channel)
      fab!(:last_private_message) { Fabricate(:chat_message, chat_channel: private_channel) }

      let(:chat_channel) { private_channel }

      before { private_channel.update!(last_message: last_private_message) }

      it "omits the last_message" do
        expect(serializer.as_json[:last_message]).to be_nil
      end
    end
  end
end
