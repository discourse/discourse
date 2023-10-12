# frozen_string_literal: true

module Chat
  module Action
    class PublishAndFollowDirectMessageChannel
      attr_reader :channel_membership

      delegate :chat_channel, :user, to: :channel_membership

      def self.call(...)
        new(...).call
      end

      def initialize(channel_membership:)
        @channel_membership = channel_membership
      end

      def call
        return unless chat_channel.direct_message_channel?
        return if users_allowing_communication.none?

        chat_channel
          .user_chat_channel_memberships
          .where(user: users_allowing_communication)
          .update_all(following: true)
        Chat::Publisher.publish_new_channel(chat_channel, users_allowing_communication)
      end

      private

      def users_allowing_communication
        @users_allowing_communication ||= User.where(id: user_ids).to_a
      end

      def user_ids
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
