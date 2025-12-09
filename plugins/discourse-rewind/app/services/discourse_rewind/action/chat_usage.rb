# frozen_string_literal: true

# Chat usage statistics
# Shows message counts, favorite channels, DM activity, etc.
module DiscourseRewind
  module Action
    class ChatUsage < BaseReport
      FakeData = {
        data: {
          total_messages: 342,
          favorite_channels: [
            { channel_id: 1, channel_slug: "general", message_count: 156 },
            { channel_id: 2, channel_slug: "tech-talk", message_count: 89 },
            { channel_id: 3, channel_slug: "random", message_count: 45 },
            { channel_id: 4, channel_slug: "dev", message_count: 32 },
            { channel_id: 5, channel_slug: "announcements", message_count: 12 },
          ],
          dm_message_count: 87,
          unique_dm_channels: 12,
          messages_with_reactions: 42,
          total_reactions_received: 156,
          avg_message_length: 78.5,
        },
        identifier: "chat-usage",
      }

      def call
        return FakeData if should_use_fake_data?
        return if !enabled?

        messages =
          Chat::Message.where(user_id: user.id).where(created_at: date).where(deleted_at: nil)

        total_messages = messages.count
        return if total_messages == 0

        # Get favorite channels (public channels)
        channel_usage =
          messages
            .joins(:chat_channel)
            .where(chat_channels: { type: "CategoryChannel" })
            .group("chat_channels.id", "chat_channels.slug")
            .count
            .sort_by { |_, count| -count }
            .first(5)
            .map do |(id, slug), count|
              { channel_id: id, channel_slug: slug, message_count: count }
            end

        # DM statistics
        dm_message_count =
          messages.joins(:chat_channel).where(chat_channels: { type: "DirectMessageChannel" }).count

        # Unique DM conversations
        unique_dm_channels =
          messages
            .joins(:chat_channel)
            .where(chat_channels: { type: "DirectMessageChannel" })
            .distinct
            .count(:chat_channel_id)

        # Messages with reactions received
        messages_with_reactions =
          Chat::MessageReaction
            .joins(:chat_message)
            .where(chat_messages: { user_id: user.id })
            .where(chat_messages: { created_at: date })
            .distinct
            .count(:chat_message_id)

        # Total reactions received
        total_reactions_received =
          Chat::MessageReaction
            .joins(:chat_message)
            .where(chat_messages: { user_id: user.id })
            .where(chat_messages: { created_at: date })
            .count

        # Average message length
        avg_message_length =
          messages.where("LENGTH(message) > 0").average("LENGTH(message)")&.to_f&.round(1) || 0

        {
          data: {
            total_messages: total_messages,
            favorite_channels: channel_usage,
            dm_message_count: dm_message_count,
            unique_dm_channels: unique_dm_channels,
            messages_with_reactions: messages_with_reactions,
            total_reactions_received: total_reactions_received,
            avg_message_length: avg_message_length,
          },
          identifier: "chat-usage",
        }
      end

      def enabled?
        Discourse.plugins_by_name["chat"]&.enabled?
      end
    end
  end
end
