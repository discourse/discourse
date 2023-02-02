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
      #   @return [Chat::Service::Base::Context]

      delegate :channel, :status, to: :context

      before_policies { context.status = context.status&.to_sym }

      policy(:invalid_access) { guardian.can_change_channel_status?(channel, status) }

      contract do
        attribute :channel
        validates :channel, presence: true

        attribute :status
        validates :status, inclusion: { in: ChatChannel.editable_statuses.keys.map(&:to_sym) }
      end

      service { channel.public_send("#{status}!", guardian.user) }
    end
  end
end
