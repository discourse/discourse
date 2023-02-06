# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for trashing a chat channel.
    # Note the slug is modified to prevent collisions.
    #
    # @example
    #  Chat::Service::TrashChannel.call(channel: channel, guardian: guardian)
    #
    class TrashChannel
      include Base

      # @!method call(channel:, guardian:)
      #   @param [ChatChannel] channel
      #   @param [Guardian] guardian
      #   @return [Chat::Service::Base::Context]

      DELETE_CHANNEL_LOG_KEY = "chat_channel_delete"

      model ChatChannel, name: :channel, key: :channel_id
      policy :invalid_access
      transaction do
        step :prevents_slug_collision
        step :soft_delete_channel
        step :log_channel_deletion
      end
      step :enqueue_delete_channel_relations_job

      private

      def invalid_access(guardian:, channel:, **)
        guardian.can_preview_chat_channel?(channel) && guardian.can_delete_chat_channel?
      end

      def prevents_slug_collision(channel:, **)
        channel.update!(
          slug:
            "#{Time.current.strftime("%Y%m%d-%H%M")}-#{channel.slug}-deleted".truncate(
              SiteSetting.max_topic_title_length,
              omission: "",
            ),
        )
      end

      def soft_delete_channel(guardian:, channel:, **)
        channel.trash!(guardian.user)
      end

      def log_channel_deletion(guardian:, channel:, **)
        StaffActionLogger.new(guardian.user).log_custom(
          DELETE_CHANNEL_LOG_KEY,
          { chat_channel_id: channel.id, chat_channel_name: channel.title(guardian.user) },
        )
      end

      def enqueue_delete_channel_relations_job(channel:, **)
        Jobs.enqueue(:chat_channel_delete, chat_channel_id: channel.id)
      end
    end
  end
end
