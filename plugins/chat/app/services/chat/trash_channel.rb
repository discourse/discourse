# frozen_string_literal: true

module Chat
  # Service responsible for trashing a chat channel.
  # Note the slug is modified to prevent collisions.
  #
  # @example
  #  Chat::TrashChannel.call(channel_id: 2, guardian: guardian)
  #
  class TrashChannel
    include Service::Base

    # @!method call(channel_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    DELETE_CHANNEL_LOG_KEY = "chat_channel_delete"

    model :channel, :fetch_channel
    policy :invalid_access
    transaction do
      step :prevents_slug_collision
      step :soft_delete_channel
      step :log_channel_deletion
    end
    step :enqueue_delete_channel_relations_job

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params[:channel_id])
    end

    def invalid_access(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel) && guardian.can_delete_chat_channel?
    end

    def prevents_slug_collision(channel:)
      channel.update!(
        slug:
          "#{Time.current.strftime("%Y%m%d-%H%M")}-#{channel.slug}-deleted".truncate(
            SiteSetting.max_topic_title_length,
            omission: "",
          ),
      )
    end

    def soft_delete_channel(guardian:, channel:)
      channel.trash!(guardian.user)
    end

    def log_channel_deletion(guardian:, channel:)
      StaffActionLogger.new(guardian.user).log_custom(
        DELETE_CHANNEL_LOG_KEY,
        { chat_channel_id: channel.id, chat_channel_name: channel.title(guardian.user) },
      )
    end

    def enqueue_delete_channel_relations_job(channel:)
      Jobs.enqueue(Jobs::Chat::ChannelDelete, chat_channel_id: channel.id)
    end
  end
end
