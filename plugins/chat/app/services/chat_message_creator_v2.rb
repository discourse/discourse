# frozen_string_literal: true

class Chat::ChatMessageCreatorV2
  class ChatMessageCreatorPayload
    attr_accessor :in_reply_to_id, :content, :staged_id, :incoming_chat_webhook, :upload_ids

    def upload_ids
      @upload_ids || []
    end
  end

  attr_reader :channel, :payload, :chat_message

  def initialize(guardian, channel, payload)
    super(guardian)
    @channel = channel
    @payload = payload
    @chat_message = initialize_message_from_payload
  end

  def execute
    execute_service_call do
      validate_channel_status!
      validate_message!
      save_and_cook
      attach_uploads
      destroy_drafts
      post_create
    end
  end

  def success_data
    { chat_message: chat_message }
  end

  private

  def initialize_message_from_payload
    ChatMessage.new(
      chat_channel: channel,
      user_id: guardian.user.id,
      last_editor_id: guardian.user.id,
      in_reply_to_id: payload.in_reply_to_id,
      message: payload.content,
    )
  end

  def validate_channel_status!
    return if guardian.can_create_channel_message?(channel)

    if channel.direct_message_channel? && !guardian.can_create_direct_message?
      fail_permissions!(I18n.t("chat.errors.user_cannot_send_direct_messages"))
    else
      fail_validation!(
        I18n.t("chat.errors.channel_new_message_disallowed", status: channel.status_name),
      )
    end
  end

  def uploads
    @uploads ||=
      if payload.upload_ids.empty? || !SiteSetting.chat_allow_uploads
        []
      else
        Upload.where(id: payload.upload_ids, user_id: guardian.user.id)
      end
  end

  def validate_message!
    chat_message.validate_message(has_uploads: uploads.any?)
    if chat_message.errors.present?
      add_errors_from(chat_message)
      fail_validation!(error_messages)
    end
  end

  def save_and_cook
    chat_message.cook
    chat_message.save!
    create_chat_webhook_event
  end

  def create_chat_webhook_event
    return if payload.incoming_chat_webhook.blank?
    ChatWebhookEvent.create(
      chat_message: chat_message,
      incoming_chat_webhook: payload.incoming_chat_webhook,
    )
  end

  def attach_uploads
    chat_message.attach_uploads(uploads)
  end

  def destroy_drafts
    ChatDraft.where(user_id: guardian.user.id, chat_channel_id: channel.id).destroy_all
  end

  def post_create
    ChatPublisher.publish_new!(channel, chat_message, payload.staged_id)
    enqueue_job(:process_chat_message, chat_message_id: chat_message.id)
    Chat::ChatNotifier.notify_new(chat_message: chat_message, timestamp: chat_message.created_at)
    channel.touch(:last_message_sent_at)
    DiscourseEvent.trigger(:chat_message_created, chat_message, channel, guardian.user)
  end
end
