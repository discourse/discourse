# frozen_string_literal: true

module Chat
  # Service responsible for marking all the channels that a user is a
  # member of _and following_ as read, including mentions.
  #
  # @example
  #  Chat::MarkAllUserChannelsRead.call(guardian: guardian)
  #
  class MarkAllUserChannelsRead
    include ::Service::Base

    # @!method call(guardian:)
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    transaction do
      step :update_last_read_message_ids
      step :mark_associated_mentions_as_read
      step :publish_user_tracking_state
    end

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
          RETURNING user_chat_channel_memberships.id AS membership_id,
                    user_chat_channel_memberships.chat_channel_id AS channel_id,
                    user_chat_channel_memberships.last_read_message_id;
        SQL
      context[:updated_memberships] = updated_memberships
    end

    def mark_associated_mentions_as_read(guardian:, updated_memberships:, **)
      return if updated_memberships.empty?

      Chat::Action::MarkMentionsRead.call(
        guardian.user,
        channel_ids: updated_memberships.map(&:channel_id),
      )
    end

    def publish_user_tracking_state(guardian:, updated_memberships:, **)
      data =
        updated_memberships.each_with_object({}) do |membership, data_hash|
          data_hash[membership.channel_id] = {
            last_read_message_id: membership.last_read_message_id,
            membership_id: membership.membership_id,
          }
        end
      Chat::Publisher.publish_bulk_user_tracking_state(guardian.user, data)
    end
  end
end
