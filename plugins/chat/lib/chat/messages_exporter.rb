# frozen_string_literal: true

module Chat
  module MessagesExporter
    LIMIT = 10_000

    def chat_message_export
      Chat::Message
        .unscoped
        .where(created_at: 6.months.ago..Time.current)
        .includes(:chat_channel)
        .includes(:user)
        .includes(:last_editor)
        .limit(LIMIT)
        .find_each do |chat_message|
          yield(
            [
              chat_message.id,
              chat_message.chat_channel.id,
              chat_message.chat_channel.name,
              chat_message.user.id,
              chat_message.user.username,
              chat_message.message,
              chat_message.cooked,
              chat_message.created_at,
              chat_message.updated_at,
              chat_message.deleted_at,
              chat_message.in_reply_to&.id,
              chat_message.last_editor&.id,
              chat_message.last_editor&.username,
            ]
          )
        end
    end

    def get_header(entity)
      if entity === "chat_message"
        %w[
          id
          chat_channel_id
          chat_channel_name
          user_id
          username
          message
          cooked
          created_at
          updated_at
          deleted_at
          in_reply_to_id
          last_editor_id
          last_editor_username
        ]
      else
        super
      end
    end
  end
end
