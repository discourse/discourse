# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for marking all the channels that a user is a
    # member of as read, including mentions.
    #
    # @example
    #  Chat::Service::MarkAllUserChannelsRead.call(guardian: guardian)
    #
    class MarkAllUserChannelsRead
      include Base

      # @!method call(guardian:)
      #   @param [Integer] channel_id
      #   @param [Integer] message_id
      #   @param [Guardian] guardian
      #   @return [Chat::Service::Base::Context]

      transaction do
        step :update_last_read_message_ids
        step :mark_associated_mentions_as_read
      end

      step :publish_new_last_read_to_clients

      private

      def update_last_read_message_ids(guardian:, **)
        updated_memberships = DB.query(<<~SQL, user_id: guardian.user.id)
          UPDATE user_chat_channel_memberships
          SET last_read_message_id = subquery.newest_message_id
          FROM
          (
            SELECT chat_messages.chat_channel_id, MAX(chat_messages.id) AS newest_message_id
            FROM chat_messages
            WHERE chat_messages.deleted_at IS NULL
            GROUP BY chat_messages.chat_channel_id
          ) AS subquery
          WHERE user_chat_channel_memberships.chat_channel_id = subquery.chat_channel_id AND
            subquery.newest_message_id > COALESCE(user_chat_channel_memberships.last_read_message_id, 0) AND
            user_chat_channel_memberships.user_id = :user_id AND
            user_chat_channel_memberships.following
          RETURNING user_chat_channel_memberships.id AS membership_id, user_chat_channel_memberships.chat_channel_id,
            user_chat_channel_memberships.last_read_message_id;
        SQL
        context[:updated_memberships] = updated_memberships
      end

      def mark_associated_mentions_as_read(guardian:, updated_memberships:, **)
        Notification
          .where(notification_type: Notification.types[:chat_mention])
          .where(user: guardian.user)
          .where(read: false)
          .joins("INNER JOIN chat_mentions ON chat_mentions.notification_id = notifications.id")
          .joins("INNER JOIN chat_messages ON chat_mentions.chat_message_id = chat_messages.id")
          .where("chat_messages.chat_channel_id IN (?)", updated_memberships.map(&:chat_channel_id))
          .update_all(read: true)
      end

      def publish_new_last_read_to_clients(guardian:, **)
        # ChatPublisher.publish_user_tracking_state(guardian.user, channel.id, contract.message_id)
      end
    end
  end
end
