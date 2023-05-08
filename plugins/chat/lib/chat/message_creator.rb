# frozen_string_literal: true
module Chat
  class MessageCreator
    attr_reader :error, :chat_message

    def self.create(opts)
      instance = new(**opts)
      instance.create
      instance
    end

    def initialize(
      chat_channel:,
      in_reply_to_id: nil,
      thread_id: nil,
      staged_thread_id: nil,
      user:,
      content:,
      staged_id: nil,
      incoming_chat_webhook: nil,
      upload_ids: nil
    )
      @chat_channel = chat_channel
      @user = user
      @guardian = Guardian.new(user)

      # NOTE: We confirm this exists and the user can access it in the ChatController,
      # but in future the checks should be here
      @in_reply_to_id = in_reply_to_id
      @content = content
      @staged_id = staged_id
      @incoming_chat_webhook = incoming_chat_webhook
      @upload_ids = upload_ids || []
      @thread_id = thread_id
      @staged_thread_id = staged_thread_id
      @error = nil

      @chat_message =
        Chat::Message.new(
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
        validate_reply_chain!
        validate_existing_thread!

        @chat_message.thread_id = @existing_thread&.id
        @chat_message.cook
        @chat_message.save!
        @chat_message.create_mentions

        create_chat_webhook_event
        create_thread
        @chat_message.attach_uploads(uploads)
        Chat::Draft.where(user_id: @user.id, chat_channel_id: @chat_channel.id).destroy_all
        Chat::Publisher.publish_new!(
          @chat_channel,
          @chat_message,
          @staged_id,
          staged_thread_id: @staged_thread_id,
        )
        resolved_thread&.increment_replies_count_cache
        Jobs.enqueue(Jobs::Chat::ProcessMessage, { chat_message_id: @chat_message.id })
        Chat::Notifier.notify_new(chat_message: @chat_message, timestamp: @chat_message.created_at)
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
                I18n.t("chat.errors.channel_new_message_disallowed.#{@chat_channel.status}"),
              )
      end
    end

    def validate_reply_chain!
      return if @in_reply_to_id.blank?

      @original_message_id = DB.query_single(<<~SQL).last
      WITH RECURSIVE original_message_finder( id, in_reply_to_id )
      AS (
        -- start with the message id we want to find the parents of
        SELECT id, in_reply_to_id
        FROM chat_messages
        WHERE id = #{@in_reply_to_id}

        UNION ALL

        -- get the chain of direct parents of the message
        -- following in_reply_to_id
        SELECT cm.id, cm.in_reply_to_id
        FROM original_message_finder rm
        JOIN chat_messages cm ON rm.in_reply_to_id = cm.id
      )
      SELECT id FROM original_message_finder

      -- this makes it so only the root parent ID is returned, we can
      -- exclude this to return all parents in the chain
      WHERE in_reply_to_id IS NULL;
    SQL

      if @original_message_id.blank?
        raise StandardError.new(I18n.t("chat.errors.original_message_not_found"))
      end

      @original_message = Chat::Message.with_deleted.find_by(id: @original_message_id)
      if @original_message&.trashed?
        raise StandardError.new(I18n.t("chat.errors.original_message_not_found"))
      end
    end

    def validate_existing_thread!
      return if @staged_thread_id.present? && @thread_id.blank?

      return if @thread_id.blank?
      @existing_thread = Chat::Thread.find(@thread_id)

      if @existing_thread.channel_id != @chat_channel.id
        raise StandardError.new(I18n.t("chat.errors.thread_invalid_for_channel"))
      end

      reply_to_thread_mismatch =
        @chat_message.in_reply_to&.thread_id &&
          @chat_message.in_reply_to.thread_id != @existing_thread.id
      original_message_has_no_thread = @original_message && @original_message.thread_id.blank?
      original_message_thread_mismatch =
        @original_message && @original_message.thread_id != @existing_thread.id
      if reply_to_thread_mismatch || original_message_has_no_thread ||
           original_message_thread_mismatch
        raise StandardError.new(I18n.t("chat.errors.thread_does_not_match_parent"))
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
      Chat::WebhookEvent.create(
        chat_message: @chat_message,
        incoming_chat_webhook: @incoming_chat_webhook,
      )
    end

    def get_uploads
      return [] if @upload_ids.blank? || !SiteSetting.chat_allow_uploads

      ::Upload.where(id: @upload_ids, user_id: @user.id)
    end

    def create_thread
      return if @in_reply_to_id.blank?
      return if @chat_message.in_thread? && !@staged_thread_id.present?

      if @original_message.thread
        thread = @original_message.thread
      else
        thread =
          Chat::Thread.create!(
            original_message: @chat_message.in_reply_to,
            original_message_user: @chat_message.in_reply_to.user,
            channel: @chat_message.chat_channel,
          )
        @chat_message.in_reply_to.thread_id = thread.id
      end

      Chat::Publisher.publish_thread_created!(
        @chat_message.chat_channel,
        @chat_message.in_reply_to,
        thread.id,
        @staged_thread_id,
      )

      @chat_message.thread_id = thread.id

      # NOTE: We intentionally do not try to correct thread IDs within the chain
      # if they are incorrect, and only set the thread ID of messages where the
      # thread ID is NULL. In future we may want some sync/background job to correct
      # any inconsistencies.
      DB.exec(<<~SQL)
        WITH RECURSIVE thread_updater AS (
          SELECT cm.id, cm.in_reply_to_id
          FROM chat_messages cm
          WHERE cm.in_reply_to_id IS NULL AND cm.id = #{@original_message_id}

          UNION ALL

          SELECT cm.id, cm.in_reply_to_id
          FROM chat_messages cm
          JOIN thread_updater ON cm.in_reply_to_id = thread_updater.id
        )
        UPDATE chat_messages
        SET thread_id = #{thread.id}
        FROM thread_updater
        WHERE thread_id IS NULL AND chat_messages.id = thread_updater.id
      SQL
    end

    def resolved_thread
      @existing_thread || @chat_message.thread
    end
  end
end
