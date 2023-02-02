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

      class DefaultContract < Contract
        attribute :status
        validates :status, inclusion: { in: ChatChannel.editable_statuses.keys.map(&:to_sym) }
      end

      delegate :channel, :status, to: :context

      model ChatChannel, name: :channel, key: :channel_id
      step :status_to_sym
      contract
      policy :invalid_access
      step :change_status

      private

      def invalid_access
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
