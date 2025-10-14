# frozen_string_literal: true

module Chat
  module Action
    module SearchMessage
      # Filters chat messages by channel slug.
      #
      # Only returns messages from channels the guardian can preview.
      class ApplyChannelFilter < Service::ActionBase
        # @param [ActiveRecord::Relation] messages The messages relation to filter
        # @param [String] match The channel slug to filter by (without the # symbol)
        # @param [Guardian] guardian The current user's guardian
        option :messages
        option :match
        option :guardian

        def call
          channel_slug = match.downcase
          channel_id = ::Chat::Channel.where(slug: channel_slug).pick(:id)

          if channel_id && guardian.can_preview_chat_channel?(::Chat::Channel.find(channel_id))
            messages.where("chat_channels.id = ?", channel_id)
          else
            messages.where("1 = 0")
          end
        end
      end
    end
  end
end
