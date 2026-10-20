# frozen_string_literal: true

module DiscourseRewind
  module Action
    class ChatUsage < BaseReport
      MINIMUM_MESSAGES = 20
      MINIMUM_DM_CHANNELS = 2

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
          total_reactions_received: 156,
          avg_message_length: 78.5,
        },
        identifier: "chat-usage",
      }

      def call
        return FakeData if should_use_fake_data?

        messages = Chat::Message.where(user_id: user.id, created_at: date)
        total_messages, avg_message_length =
          messages.pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("AVG(LENGTH(message)) FILTER (WHERE LENGTH(message) > 0)"),
          )

        return if total_messages < MINIMUM_MESSAGES

        favorite_channels =
          messages
            .joins(:chat_channel)
            .merge(self.class.public_category_channels)
            .group("chat_channels.id", "chat_channels.slug")
            .order("COUNT(*) DESC", "chat_channels.id")
            .limit(5)
            .count
            .map do |(channel_id, channel_slug), message_count|
              { channel_id:, channel_slug:, message_count: }
            end

        dm_message_count, unique_dm_channels =
          messages.in_dm_channel.pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(DISTINCT chat_messages.chat_channel_id)"),
          )

        return if unique_dm_channels < MINIMUM_DM_CHANNELS || favorite_channels.empty?

        {
          data: {
            total_messages:,
            favorite_channels:,
            dm_message_count:,
            unique_dm_channels:,
            total_reactions_received:
              Chat::MessageReaction.where(chat_message_id: messages.select(:id)).count,
            avg_message_length: avg_message_length.to_f.round(1),
          },
          identifier: "chat-usage",
        }
      end

      def self.public_category_channels
        Chat::Channel.public_channels.where(categories: { read_restricted: false })
      end

      def self.filter_for_viewer(report, **)
        favorite_channels = report[:data][:favorite_channels]
        public_channel_ids =
          public_category_channels.where(id: favorite_channels.pluck(:channel_id)).pluck(:id)

        report.deep_merge(
          data: {
            favorite_channels:
              favorite_channels.select { |channel| channel[:channel_id].in?(public_channel_ids) },
          },
        )
      end

      def self.enabled?
        plugin_enabled?("chat")
      end
    end
  end
end
