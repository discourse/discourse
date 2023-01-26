# frozen_string_literal: true

class Chat::ChannelDestroyer
  include ChatService

  before_contract { guardian(:can_delete_chat_channel?) }

  contract do
    attribute :channel
    validates :channel, presence: true
  end

  service do
    delete_channel
    enqueue_delete_channel_relations_job
  end

  private def delete_channel
    ChatChannel.transaction do
      prevents_slug_collision
      context.channel.trash!(context.guardian.user)
      log_channel_deletion
    end
  end

  private def enqueue_delete_channel_relations_job
    Jobs.enqueue(:chat_channel_delete, chat_channel_id: context.channel.id)
  end

  private def log_channel_deletion
    StaffActionLogger.new(context.guardian.user).log_custom(
      "chat_channel_delete",
      {
        chat_channel_id: context.channel.id,
        chat_channel_name: context.channel.title(context.guardian.user),
      },
    )
  end

  private def prevents_slug_collision
    context.channel.update!(slug: generate_deleted_slug)
  end

  private def generate_deleted_slug
    "#{Time.now.strftime("%Y%m%d-%H%M")}-#{context.channel.slug}-deleted".truncate(
      SiteSetting.max_topic_title_length,
      omission: "",
    )
  end
end
