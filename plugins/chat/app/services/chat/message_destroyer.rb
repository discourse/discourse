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

    private

    def reset_last_read(message_ids)
      Chat::UserChatChannelMembership.where(last_read_message_id: message_ids).update_all(
        last_read_message_id: nil,
      )
    end

    def delete_flags(message_ids)
      Chat::ReviewableMessage.where(target_id: message_ids).destroy_all
    end
  end
end
