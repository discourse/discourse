# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for updating a chat channel status.
    #
    # @example
    #  Chat::Service::UpdateChannelStatus.call(channel: channel, guardian: guardian, status: "open")
    #
    class UpdateChannelStatus
      include Base

      # @!method call(channel:, guardian:, status:)
      #   @param [ChatChannel] channel
      #   @param [Guardian] guardian
      #   @param [String] status
      #   @return [Context]

      before_contract { context.status = context.status&.to_sym }
      before_contract { guardian(:can_change_channel_status?, context.channel, context.status) }

      contract do
        attribute :channel
        validates :channel, presence: true

        attribute :status, :symbol
        # we only want to use this endpoint for open/closed status changes,
        # the others are more "special" and are handled by the archive endpoint
        validates :status,
                  presence: true,
                  in:
                    ChatChannel.statuses.keys.reject { |status|
                      status == "read_only" || status == "archive"
                    }
      end

      service { context.channel.public_send("#{context.status}!", context.guardian.user) }
    end
  end
end
