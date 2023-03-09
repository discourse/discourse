# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for updating the last read message id of a membership.
    #
    # @example
    #  Chat::Service::UpdateUserLastRead.call(channel_id: 2, message_id: 3, guardian: guardian)
    #
    class UpdateUserLastRead
      include Base

      # @!method call(user_id:, channel_id:, message_id:, guardian:)
      #   @param [Integer] channel_id
      #   @param [Integer] message_id
      #   @param [Guardian] guardian
      #   @return [Chat::Service::Base::Context]

      contract
      model :channel
      model :active_membership
      policy :invalid_access
      policy :ensure_message_exists
      policy :ensure_message_id_recency
      step :update_last_read_message_id
      step :mark_associated_mentions_as_read
      step :publish_new_last_read_to_clients

      # @!visibility private
      class Contract
        attribute :message_id, :integer
        attribute :channel_id, :integer

        validates :message_id, :channel_id, presence: true
      end

      private

      def fetch_channel(contract:, **)
        ChatChannel.find_by(id: contract.channel_id)
      end

      def fetch_active_membership(guardian:, channel:, **)
        Chat::ChatChannelMembershipManager.new(channel).find_for_user(
          guardian.user,
          following: true,
        )
      end

      def invalid_access(guardian:, active_membership:, **)
        guardian.can_join_chat_channel?(active_membership.chat_channel)
      end

      def ensure_message_exists(channel:, contract:, **)
        ChatMessage.with_deleted.exists?(chat_channel_id: channel.id, id: contract.message_id)
      end

      def ensure_message_id_recency(contract:, active_membership:, **)
        !active_membership.last_read_message_id ||
          contract.message_id >= active_membership.last_read_message_id
      end

      def update_last_read_message_id(contract:, active_membership:, **)
        active_membership.update!(last_read_message_id: contract.message_id)
      end

      def mark_associated_mentions_as_read(active_membership:, contract:, **)
        Notification
          .where(notification_type: Notification.types[:chat_mention])
          .where(user: active_membership.user)
          .where(read: false)
          .joins("INNER JOIN chat_mentions ON chat_mentions.notification_id = notifications.id")
          .joins("INNER JOIN chat_messages ON chat_mentions.chat_message_id = chat_messages.id")
          .where("chat_messages.id <= ?", contract.message_id)
          .where("chat_messages.chat_channel_id = ?", active_membership.chat_channel.id)
          .update_all(read: true)
      end

      def publish_new_last_read_to_clients(guardian:, channel:, contract:, **)
        ChatPublisher.publish_user_tracking_state(guardian.user, channel.id, contract.message_id)
      end
    end
  end
end
