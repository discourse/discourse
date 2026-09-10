# frozen_string_literal: true

module Chat
  module McpTools
    class ListChannels
      def self.call(arguments:, request_context:)
        result = Chat::ListUserChannels.call(guardian: request_context.guardian)
        raise DiscourseMcp::ToolError, "Unable to list chat channels" if result.failure?
        structured = result.structured
        channels =
          (structured[:public_channels] + structured[:direct_message_channels]).map do |channel|
            {
              id: channel.id,
              title: channel.title(request_context.user),
              status: channel.status,
              direct_message: channel.direct_message_channel?,
            }
          end
        DiscourseMcp::ToolHelpers.text_and_structured(channels: channels)
      end
    end

    class ListMessages
      def self.call(arguments:, request_context:)
        result =
          Chat::ListChannelMessages.call(
            params: {
              channel_id: arguments.fetch("channel_id"),
              page_size: arguments.fetch("limit", 50),
            },
            guardian: request_context.guardian,
          )
        raise DiscourseMcp::ToolError, "Unable to list chat messages" if result.failure?
        messages =
          Array(result.messages).map do |message|
            {
              id: message.id,
              channel_id: message.chat_channel_id,
              user_id: message.user_id,
              username: message.user&.username,
              message: message.message,
              created_at: message.created_at.iso8601,
              thread_id: message.thread_id,
            }
          end
        DiscourseMcp::ToolHelpers.text_and_structured(messages: messages)
      end
    end

    class CreateMessage
      def self.call(arguments:, request_context:)
        result =
          Chat::CreateMessage.call(
            params: {
              chat_channel_id: arguments.fetch("channel_id"),
              message: arguments.fetch("message"),
              thread_id: arguments["thread_id"],
              in_reply_to_id: arguments["reply_to_message_id"],
            },
            guardian: request_context.guardian,
          )
        raise DiscourseMcp::ToolError, "Unable to create chat message" if result.failure?
        message = result.message_instance
        DiscourseMcp::ToolHelpers.text_and_structured(
          id: message.id,
          channel_id: message.chat_channel_id,
          created_at: message.created_at.iso8601,
        )
      end
    end
  end
end
