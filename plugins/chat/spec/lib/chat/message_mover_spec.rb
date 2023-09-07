# frozen_string_literal: true

require "rails_helper"

describe Chat::MessageMover do
  fab!(:acting_user) { Fabricate(:admin, username: "testmovechat") }
  fab!(:source_channel) { Fabricate(:category_channel) }
  fab!(:destination_channel) { Fabricate(:category_channel) }

  fab!(:message1) do
    Fabricate(
      :chat_message,
      chat_channel: source_channel,
      created_at: 3.minutes.ago,
      message: "the first to be moved",
    )
  end
  fab!(:message2) do
    Fabricate(
      :chat_message,
      chat_channel: source_channel,
      created_at: 2.minutes.ago,
      message: "message deux @testmovechat",
    )
  end
  fab!(:message3) do
    Fabricate(
      :chat_message,
      chat_channel: source_channel,
      created_at: 1.minute.ago,
      message: "the third message",
    )
  end
  fab!(:message4) { Fabricate(:chat_message, chat_channel: destination_channel) }
  fab!(:message5) { Fabricate(:chat_message, chat_channel: destination_channel) }
  fab!(:message6) { Fabricate(:chat_message, chat_channel: destination_channel) }

  let(:move_message_ids) { [message1.id, message2.id, message3.id] }

  before { source_channel.update!(last_message: message3) }

  describe "#move_to_channel" do
    def move!(move_message_ids = [message1.id, message2.id, message3.id])
      described_class.new(
        acting_user: acting_user,
        source_channel: source_channel,
        message_ids: move_message_ids,
      ).move_to_channel(destination_channel)
    end

    it "raises an error if either the source or destination channels are not public (they cannot be DM channels)" do
      expect {
        described_class.new(
          acting_user: acting_user,
          source_channel: Fabricate(:direct_message_channel),
          message_ids: move_message_ids,
        ).move_to_channel(destination_channel)
      }.to raise_error(Chat::MessageMover::InvalidChannel)
      expect {
        described_class.new(
          acting_user: acting_user,
          source_channel: source_channel,
          message_ids: move_message_ids,
        ).move_to_channel(Fabricate(:direct_message_channel))
      }.to raise_error(Chat::MessageMover::InvalidChannel)
    end

    it "raises an error if no messages are found using the message ids" do
      other_channel = Fabricate(:chat_channel)
      message1.update(chat_channel: other_channel)
      message2.update(chat_channel: other_channel)
      message3.update(chat_channel: other_channel)
      expect { move! }.to raise_error(Chat::MessageMover::NoMessagesFound)
    end

    it "deletes the messages from the source channel and sends messagebus delete messages" do
      messages = MessageBus.track_publish { move! }
      expect(Chat::Message.where(id: move_message_ids)).to eq([])
      deleted_messages = Chat::Message.with_deleted.where(id: move_message_ids).order(:id)
      expect(deleted_messages.count).to eq(3)
      expect(messages.first.channel).to eq("/chat/#{source_channel.id}")
      expect(messages.first.data["type"]).to eq("bulk_delete")
      expect(messages.first.data["deleted_ids"]).to eq(deleted_messages.map(&:id))
      expect(messages.first.data["deleted_at"]).not_to eq(nil)
    end

    it "creates a message in the source channel to indicate that the messages have been moved" do
      move!
      placeholder_message =
        Chat::Message.where(chat_channel: source_channel).order(:created_at).last
      destination_first_moved_message =
        Chat::Message.find_by(chat_channel: destination_channel, message: "the first to be moved")
      expect(placeholder_message.message).to eq(
        I18n.t(
          "chat.channel.messages_moved",
          count: move_message_ids.length,
          acting_username: acting_user.username,
          channel_name: destination_channel.title(acting_user),
          first_moved_message_url: destination_first_moved_message.url,
        ),
      )
    end

    it "preserves the order of the messages in the destination channel" do
      move!
      moved_messages =
        Chat::Message
          .where(chat_channel: destination_channel)
          .order("created_at ASC, id ASC")
          .last(3)
      expect(moved_messages.map(&:message)).to eq(
        ["the first to be moved", "message deux @testmovechat", "the third message"],
      )
    end

    it "updates references for reactions, uploads, revisions, mentions, etc." do
      reaction = Fabricate(:chat_message_reaction, chat_message: message1)
      upload = Fabricate(:upload_reference, target: message1)
      mention = Fabricate(:chat_mention, chat_message: message2, user: acting_user)
      revision = Fabricate(:chat_message_revision, chat_message: message3)
      webhook_event = Fabricate(:chat_webhook_event, chat_message: message3)
      move!

      moved_messages =
        Chat::Message
          .where(chat_channel: destination_channel)
          .order("created_at ASC, id ASC")
          .last(3)
      expect(reaction.reload.chat_message_id).to eq(moved_messages.first.id)
      expect(upload.reload.target_id).to eq(moved_messages.first.id)
      expect(mention.reload.chat_message_id).to eq(moved_messages.second.id)
      expect(revision.reload.chat_message_id).to eq(moved_messages.third.id)
      expect(webhook_event.reload.chat_message_id).to eq(moved_messages.third.id)
    end

    it "does not preserve reply chains using in_reply_to_id" do
      message3.update!(in_reply_to: message2)
      message2.update!(in_reply_to: message1)
      move!
      moved_messages =
        Chat::Message
          .where(chat_channel: destination_channel)
          .order("created_at ASC, id ASC")
          .last(3)

      expect(moved_messages.pluck(:in_reply_to_id).uniq).to eq([nil])
    end

    it "clears in_reply_to_id for remaining messages when the messages they were replying to are moved" do
      message3.update!(in_reply_to: message2)
      message2.update!(in_reply_to: message1)
      move!([message2.id])
      expect(message3.reload.in_reply_to_id).to eq(nil)
    end

    context "when there is a thread" do
      fab!(:thread) { Fabricate(:chat_thread, channel: source_channel, original_message: message1) }

      before do
        message1.update!(thread: thread)
        message2.update!(thread: thread)
        message3.update!(thread: thread)
      end

      it "does not preserve thread_ids" do
        move!
        moved_messages =
          Chat::Message
            .where(chat_channel: destination_channel)
            .order("created_at ASC, id ASC")
            .last(3)

        expect(moved_messages.pluck(:thread_id).uniq).to eq([nil])
      end

      it "deletes the empty thread" do
        move!
        expect(Chat::Thread.exists?(id: thread.id)).to eq(false)
      end

      it "clears in_reply_to_id for remaining messages when the messages they were replying to are moved but leaves the thread_id" do
        message3.update!(in_reply_to: message2)
        message2.update!(in_reply_to: message1)
        move!([message2.id])
        expect(message3.reload.in_reply_to_id).to eq(nil)
        expect(message3.reload.thread).to eq(thread)
      end

      it "updates the tracking to the last non-deleted channel message for users whose last_read_message_id was the moved message" do
        membership_1 =
          Fabricate(
            :user_chat_channel_membership,
            chat_channel: source_channel,
            last_read_message: message1,
          )
        membership_2 =
          Fabricate(
            :user_chat_channel_membership,
            chat_channel: source_channel,
            last_read_message: message2,
          )
        membership_3 =
          Fabricate(
            :user_chat_channel_membership,
            chat_channel: source_channel,
            last_read_message: message3,
          )
        move!([message2.id])
        expect(membership_1.reload.last_read_message_id).to eq(message1.id)
        expect(membership_2.reload.last_read_message_id).to eq(message3.id)
        expect(membership_3.reload.last_read_message_id).to eq(message3.id)
      end

      context "when a thread original message is moved" do
        it "creates a new thread for the messages left behind in the old channel" do
          message4 =
            Fabricate(
              :chat_message,
              chat_channel: source_channel,
              message: "the fourth message",
              in_reply_to: message3,
              thread: thread,
            )
          message5 =
            Fabricate(
              :chat_message,
              chat_channel: source_channel,
              message: "the fifth message",
              thread: thread,
            )
          expect { move! }.to change { Chat::Thread.count }.by(1)
          new_thread = Chat::Thread.last
          expect(message4.reload.thread_id).to eq(new_thread.id)
          expect(message5.reload.thread_id).to eq(new_thread.id)
          expect(new_thread.channel).to eq(source_channel)
          expect(new_thread.original_message).to eq(message4)
        end
      end

      context "when multiple thread original messages are moved" do
        it "works the same as when one is" do
          message4 =
            Fabricate(:chat_message, chat_channel: source_channel, message: "the fourth message")
          message5 =
            Fabricate(
              :chat_message,
              chat_channel: source_channel,
              in_reply_to: message5,
              message: "the fifth message",
            )
          other_thread =
            Fabricate(:chat_thread, channel: source_channel, original_message: message4)
          message4.update!(thread: other_thread)
          message5.update!(thread: other_thread)
          expect { move!([message1.id, message4.id]) }.to change { Chat::Thread.count }.by(2)

          new_threads = Chat::Thread.order(:created_at).last(2)
          expect(message3.reload.thread_id).to eq(new_threads.first.id)
          expect(message5.reload.thread_id).to eq(new_threads.second.id)
          expect(new_threads.first.channel).to eq(source_channel)
          expect(new_threads.second.channel).to eq(source_channel)
          expect(new_threads.first.original_message).to eq(message2)
          expect(new_threads.second.original_message).to eq(message5)
        end
      end
    end
  end
end
