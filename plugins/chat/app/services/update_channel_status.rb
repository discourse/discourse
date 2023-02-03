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

      model ChatChannel, name: :channel, key: :channel_id
      step :status_to_sym
      contract
      policy :check_channel_permission
      step :change_status

      class Contract
        attribute :status
        validates :status, inclusion: { in: ChatChannel.editable_statuses.keys.map(&:to_sym) }
      end

      delegate :channel, :status, to: :context

      private

      def check_channel_permission
        guardian.can_preview_chat_channel?(channel) &&
          guardian.can_change_channel_status?(channel, status)
      end

      def status_to_sym
        context.status = context.status&.to_sym
      end

      def change_status
        channel.public_send("#{status}!", guardian.user)
      end
    end
  end
end
