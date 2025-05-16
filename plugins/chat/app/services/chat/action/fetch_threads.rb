# frozen_string_literal: true

module Chat
  module Action
    class FetchThreads < Service::ActionBase
      option :user_id
      option :channel_id
      option :limit
      option :offset

      def call
        ::Chat::Thread
          .includes(
            :channel,
            :user_chat_thread_memberships,
            original_message_user: :user_status,
            last_message: [
              :uploads,
              :chat_webhook_event,
              :chat_channel,
              user_mentions: {
                user: :user_status,
              },
              user: :user_status,
            ],
            original_message: [
              :uploads,
              :chat_webhook_event,
              :chat_channel,
              user_mentions: {
                user: :user_status,
              },
              user: :user_status,
            ],
          )
          .joins(
            "LEFT JOIN user_chat_thread_memberships ON chat_threads.id = user_chat_thread_memberships.thread_id AND user_chat_thread_memberships.user_id = #{user_id} AND user_chat_thread_memberships.notification_level NOT IN (#{::Chat::UserChatThreadMembership.notification_levels[:muted]})",
          )
          .joins(
            "LEFT JOIN chat_messages AS last_message ON chat_threads.last_message_id = last_message.id",
          )
          .joins(
            "INNER JOIN chat_messages AS original_message ON chat_threads.original_message_id = original_message.id",
          )
          .where(channel_id:)
          .where("original_message.chat_channel_id = chat_threads.channel_id")
          .where("original_message.deleted_at IS NULL")
          .where("last_message.chat_channel_id = chat_threads.channel_id")
          .where("last_message.deleted_at IS NULL")
          .where("chat_threads.replies_count > 0")
          .order(
            "CASE WHEN user_chat_thread_memberships.last_read_message_id IS NULL OR user_chat_thread_memberships.last_read_message_id < chat_threads.last_message_id THEN true ELSE false END DESC, last_message.created_at DESC",
          )
          .limit(limit)
          .offset(offset)
      end
    end
  end
end
