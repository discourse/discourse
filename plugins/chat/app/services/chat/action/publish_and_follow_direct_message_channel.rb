# frozen_string_literal: true

module Chat
  module Action
    class PublishAndFollowDirectMessageChannel < Service::ActionBase
      option :channel_membership

      delegate :chat_channel, :user, to: :channel_membership

      def call
        return if !chat_channel.direct_message_channel?
        return if user_ids.empty?

        chat_channel
          .user_chat_channel_memberships
          .where(user_id: user_ids)
          .update_all(following: true)

        Chat::Publisher.publish_new_channel(chat_channel, user_ids)
      end

      private

      def user_ids
        @user_ids ||=
          UserCommScreener.new(
            acting_user: user,
            target_user_ids:
              chat_channel.user_chat_channel_memberships.where(following: false).pluck(:user_id),
          ).allowing_actor_communication + Array.wrap(current_user_id)
      end

      def current_user_id
        return if channel_membership.following?
        user.id
      end
    end
  end
end
