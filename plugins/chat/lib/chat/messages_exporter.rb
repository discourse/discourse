# frozen_string_literal: true

module Chat
  module MessagesExporter
    LIMIT = 10_000

    def chat_message_export
      Chat::Message
        .unscoped
        .where(created_at: 6.months.ago..Time.current)
        .joins(:chat_channel)
        .joins(:user)
        .joins("INNER JOIN users last_editors ON chat_messages.last_editor_id = last_editors.id")
        .order(:created_at)
        .limit(LIMIT)
        .pluck(
          "chat_messages.id",
          "chat_channels.id",
          "chat_channels.name",
          "users.id",
          "users.username",
          "chat_messages.message",
          "chat_messages.cooked",
          "chat_messages.created_at",
          "chat_messages.updated_at",
          "chat_messages.deleted_at",
          "chat_messages.in_reply_to_id",
          "last_editors.id",
          "last_editors.username",
        )
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
