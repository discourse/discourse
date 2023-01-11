# frozen_string_literal: true
class Chat::ChatMessageCreator
  attr_reader :error, :chat_message

  def self.create(opts)
    instance = new(**opts)
    instance.create
    instance
  end

  def initialize(
    chat_channel:,
    in_reply_to_id: nil,
    user:,
    content:,
    staged_id: nil,
    incoming_chat_webhook: nil,
    upload_ids: nil
  )
    @chat_channel = chat_channel
    @user = user
    @guardian = Guardian.new(user)
    @in_reply_to_id = in_reply_to_id
    @content = content
    @staged_id = staged_id
    @incoming_chat_webhook = incoming_chat_webhook
    @upload_ids = upload_ids || []
    @error = nil

    @chat_message =
      ChatMessage.new(
        chat_channel: @chat_channel,
        user_id: @user.id,
        last_editor_id: @user.id,
        in_reply_to_id: @in_reply_to_id,
        message: @content,
      )
  end

  def create
    begin
      validate_channel_status!
      uploads = get_uploads
      validate_message!(has_uploads: uploads.any?)
      @chat_message.cook
      @chat_message.save!
      create_chat_webhook_event
      @chat_message.attach_uploads(uploads)
      ChatDraft.where(user_id: @user.id, chat_channel_id: @chat_channel.id).destroy_all
      ChatPublisher.publish_new!(@chat_channel, @chat_message, @staged_id)
      Jobs.enqueue(:process_chat_message, { chat_message_id: @chat_message.id })
      Chat::ChatNotifier.notify_new(
        chat_message: @chat_message,
        timestamp: @chat_message.created_at,
      )
      @chat_channel.touch(:last_message_sent_at)
      DiscourseEvent.trigger(:chat_message_created, @chat_message, @chat_channel, @user)
    rescue => error
      @error = error
    end
  end

  def failed?
    @error.present?
  end

  private

  def validate_channel_status!
    return if @guardian.can_create_channel_message?(@chat_channel)

    if @chat_channel.direct_message_channel? && !@guardian.can_create_direct_message?
      raise StandardError.new(I18n.t("chat.errors.user_cannot_send_direct_messages"))
    else
      raise StandardError.new(
              I18n.t(
                "chat.errors.channel_new_message_disallowed",
                status: @chat_channel.status_name,
              ),
            )
    end
  end

  def validate_message!(has_uploads:)
    @chat_message.validate_message(has_uploads: has_uploads)
    if @chat_message.errors.present?
      raise StandardError.new(@chat_message.errors.map(&:full_message).join(", "))
    end
  end

  def create_chat_webhook_event
    return if @incoming_chat_webhook.blank?
    ChatWebhookEvent.create(
      chat_message: @chat_message,
      incoming_chat_webhook: @incoming_chat_webhook,
    )
  end

  def get_uploads
    return [] if @upload_ids.blank? || !SiteSetting.chat_allow_uploads

    Upload.where(id: @upload_ids, user_id: @user.id)
  end
end
