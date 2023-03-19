# frozen_string_literal: true

module Chat
  # Service responsible for updating the last read message id of a membership.
  #
  # @example
  #  Chat::UpdateUserLastRead.call(user_id: 1, channel_id: 2, message_id: 3, guardian: guardian)
  #
  class UpdateUserLastRead
    include Service::Base

    # @!method call(user_id:, channel_id:, message_id:, guardian:)
    #   @param [Integer] user_id
    #   @param [Integer] channel_id
    #   @param [Integer] message_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :membership, :fetch_active_membership
    policy :invalid_access
    policy :ensure_message_id_recency
    policy :ensure_message_exists
    step :update_last_read_message_id
    step :mark_associated_mentions_as_read
    step :publish_new_last_read_to_clients

    # @!visibility private
    class Contract
      attribute :message_id, :integer
      attribute :user_id, :integer
      attribute :channel_id, :integer

      validates :message_id, :user_id, :channel_id, presence: true
    end

    private

    def fetch_active_membership(user_id:, channel_id:, **)
      Chat::UserChatChannelMembership.includes(:user, :chat_channel).find_by(
        user_id: user_id,
        chat_channel_id: channel_id,
        following: true,
      )
    end

    def invalid_access(guardian:, membership:, **)
      guardian.can_join_chat_channel?(membership.chat_channel)
    end

    def ensure_message_id_recency(message_id:, membership:, **)
      !membership.last_read_message_id || message_id >= membership.last_read_message_id
    end

    def ensure_message_exists(channel_id:, message_id:, **)
      Chat::Message.with_deleted.exists?(chat_channel_id: channel_id, id: message_id)
    end

    def update_last_read_message_id(message_id:, membership:, **)
      membership.update!(last_read_message_id: message_id)
    end

    def mark_associated_mentions_as_read(membership:, message_id:, **)
      Notification
        .where(notification_type: Notification.types[:chat_mention])
        .where(user: membership.user)
        .where(read: false)
        .joins("INNER JOIN chat_mentions ON chat_mentions.notification_id = notifications.id")
        .joins("INNER JOIN chat_messages ON chat_mentions.chat_message_id = chat_messages.id")
        .where("chat_messages.id <= ?", message_id)
        .where("chat_messages.chat_channel_id = ?", membership.chat_channel.id)
        .update_all(read: true)
    end

    def publish_new_last_read_to_clients(guardian:, channel_id:, message_id:, **)
      Chat::Publisher.publish_user_tracking_state(guardian.user, channel_id, message_id)
    end
  end
end
