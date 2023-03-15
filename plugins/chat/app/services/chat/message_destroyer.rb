# frozen_string_literal: true

module Chat
  class MessageDestroyer
    def destroy_in_batches(chat_messages_query, batch_size: 200)
      chat_messages_query
        .in_batches(of: batch_size)
        .each do |relation|
          destroyed_ids = relation.destroy_all.pluck(:id)
          reset_last_read(destroyed_ids)
          delete_flags(destroyed_ids)
        end
    end

    def trash_message(message, actor)
      Chat::Message.transaction do
        message.trash!(actor)
        Chat::Mention.where(chat_message: message).destroy_all
        DiscourseEvent.trigger(:chat_message_trashed, message, message.chat_channel, actor)

        # FIXME: We should do something to prevent the blue/green bubble
        # of other channel members from getting out of sync when a message
        # gets deleted.
        Chat::Publisher.publish_delete!(message.chat_channel, message)
      end
    end

    private

    def reset_last_read(message_ids)
      Chat::UserChatChannelMembership.where(last_read_message_id: message_ids).update_all(
        last_read_message_id: nil,
      )
    end

    def delete_flags(message_ids)
      Chat::ReviewableChatMessage.where(target_id: message_ids).destroy_all
    end
  end
end
