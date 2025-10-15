# frozen_string_literal: true

module Chat
  module Action
    module SearchMessage
      # Filters chat messages by channel slug.
      #
      # Only returns messages from channels the guardian can preview.
      class ApplyChannelFilter < Service::ActionBase
        # @param [ActiveRecord::Relation] messages The messages relation to filter
        # @param [String] channel_slug The channel slug to filter by (without the # symbol)
        # @param [Guardian] guardian The current user's guardian
        option :messages
        option :channel_slug
        option :guardian

        def call
          channel = ::Chat::Channel.find_by(slug: channel_slug.downcase)

          if channel.present? && guardian.can_preview_chat_channel?(channel)
            messages.where("chat_channels.id = ?", channel_id)
          else
            messages.where("1 = 0")
          end
        end
      end
    end
  end
end
