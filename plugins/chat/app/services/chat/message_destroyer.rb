# frozen_string_literal: true

module Chat
  class MessageDestroyer
    def destroy_in_batches(chat_messages_query, batch_size: 200)
      chat_messages_query
        .in_batches(of: batch_size)
        .each do |relation|
          Chat::Message.transaction do
            messages = relation.to_a
            destroyed_ids =
              messages.filter_map do |message|
                removed = message.deleted_at.present?
                next unless message.destroy
                DsaModeration.record_removal(message) unless removed
                [message.id, message.chat_channel_id]
              end
            destroyed_message_ids = destroyed_ids.map(&:first).uniq
            destroyed_message_channel_ids = destroyed_ids.map(&:second).uniq

            # This needs to be done before reset_last_read so we can lean on the last_message_id
            # there.
            reset_last_message_ids(destroyed_message_ids, destroyed_message_channel_ids)

            reset_last_read(destroyed_message_ids, destroyed_message_channel_ids)
            delete_flags(destroyed_message_ids)
            DsaModeration.flush
          end
        end
    end

    private

    def reset_last_message_ids(destroyed_message_ids, destroyed_message_channel_ids)
      ::Chat::Action::ResetChannelsLastMessageIds.call(
        destroyed_message_ids,
        destroyed_message_channel_ids,
      )
    end

    def reset_last_read(destroyed_message_ids, destroyed_message_channel_ids)
      ::Chat::Action::ResetUserLastReadChannelMessage.call(
        destroyed_message_ids,
        destroyed_message_channel_ids,
      )
    end

    def delete_flags(message_ids)
      Chat::ReviewableMessage.where(target_id: message_ids).destroy_all
    end
  end
end
