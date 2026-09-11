# frozen_string_literal: true

module Chat
  module McpTools
    class ListChannels
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          channels: {
            type: "array",
            items:
              DiscourseMcp::OutputSchema.object(
                id: DiscourseMcp::OutputSchema::INTEGER,
                title: DiscourseMcp::OutputSchema::STRING,
                status: DiscourseMcp::OutputSchema::STRING,
                direct_message: DiscourseMcp::OutputSchema::BOOLEAN,
              ),
          },
        )

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
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          channel_id: DiscourseMcp::OutputSchema::INTEGER,
          messages: {
            type: "array",
            items:
              DiscourseMcp::OutputSchema.object(
                id: DiscourseMcp::OutputSchema::INTEGER,
                channel_id: DiscourseMcp::OutputSchema::INTEGER,
                user_id: DiscourseMcp::OutputSchema::INTEGER_OR_NULL,
                username: DiscourseMcp::OutputSchema::STRING_OR_NULL,
                message: DiscourseMcp::OutputSchema::STRING,
                created_at: DiscourseMcp::OutputSchema::STRING,
                edited: DiscourseMcp::OutputSchema::BOOLEAN,
                thread_id: DiscourseMcp::OutputSchema::INTEGER_OR_NULL,
                in_reply_to_id: DiscourseMcp::OutputSchema::INTEGER_OR_NULL,
              ),
          },
          meta: DiscourseMcp::OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        result =
          Chat::ListChannelMessages.call(
            params: {
              channel_id: arguments.fetch("channel_id"),
              page_size: arguments.fetch("page_size", 50),
              target_message_id: arguments["target_message_id"],
              direction: arguments["direction"],
              target_date: arguments["target_date"],
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
              edited: message.revisions.any?,
              thread_id: message.thread_id,
              in_reply_to_id: message.in_reply_to_id,
            }
          end
        metadata = result.metadata || {}
        DiscourseMcp::ToolHelpers.text_and_structured(
          channel_id: arguments.fetch("channel_id"),
          messages:,
          meta: {
            returned: messages.length,
            can_load_more_past: metadata[:can_load_more_past],
            can_load_more_future: metadata[:can_load_more_future],
            target_message_id: metadata[:target_message_id] || arguments["target_message_id"],
          },
        )
      end
    end

    class CreateMessage
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          id: DiscourseMcp::OutputSchema::INTEGER,
          channel_id: DiscourseMcp::OutputSchema::INTEGER,
          created_at: DiscourseMcp::OutputSchema::STRING,
        )

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
