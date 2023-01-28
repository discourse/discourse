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

      contract do
        attribute :channel
        validates :channel, presence: true

        attribute :status
        validates :status, inclusion: { in: ChatChannel.editable_statuses.keys.map(&:to_sym) }
      end

      before_service { guardian(:can_change_channel_status?, context.channel, context.status) }

      service { context.channel.public_send("#{context.status}!", context.guardian.user) }
    end
  end
end
