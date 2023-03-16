# frozen_string_literal: true

module Chat
  class MessageUpdater
    attr_reader :error

    def self.update(opts)
      instance = new(**opts)
      instance.update
      instance
    end

    def initialize(guardian:, chat_message:, new_content:, upload_ids: nil)
      @guardian = guardian
      @user = guardian.user
      @chat_message = chat_message
      @old_message_content = chat_message.message
      @chat_channel = @chat_message.chat_channel
      @new_content = new_content
      @upload_ids = upload_ids
      @error = nil
    end

    def update
      begin
        validate_channel_status!
        @guardian.ensure_can_edit_chat!(@chat_message)
        @chat_message.message = @new_content
        @chat_message.last_editor_id = @user.id
        upload_info = get_upload_info
        validate_message!(has_uploads: upload_info[:uploads].any?)
        @chat_message.cook
        @chat_message.save!
        update_uploads(upload_info)
        revision = save_revision!
        @chat_message.reload
        Chat::Publisher.publish_edit!(@chat_channel, @chat_message)
        Jobs.enqueue(Jobs::Chat::ProcessMessage, { chat_message_id: @chat_message.id })
        Chat::Notifier.notify_edit(chat_message: @chat_message, timestamp: revision.created_at)
        DiscourseEvent.trigger(:chat_message_edited, @chat_message, @chat_channel, @user)
      rescue => error
        @error = error
      end
    end

    def failed?
      @error.present?
    end

    private

    def validate_channel_status!
      return if @guardian.can_modify_channel_message?(@chat_channel)
      raise StandardError.new(
              I18n.t("chat.errors.channel_modify_message_disallowed.#{@chat_channel.status}"),
            )
    end

    def validate_message!(has_uploads:)
      @chat_message.validate_message(has_uploads: has_uploads)
      if @chat_message.errors.present?
        raise StandardError.new(@chat_message.errors.map(&:full_message).join(", "))
      end
    end

    def get_upload_info
      return { uploads: [] } if @upload_ids.nil? || !SiteSetting.chat_allow_uploads

      uploads = ::Upload.where(id: @upload_ids, user_id: @user.id)
      if uploads.count != @upload_ids.count
        # User is passing upload_ids for uploads that they don't own. Don't change anything.
        return { uploads: @chat_message.uploads, changed: false }
      end

      new_upload_ids = uploads.map(&:id)
      existing_upload_ids = @chat_message.upload_ids
      difference = (existing_upload_ids + new_upload_ids) - (existing_upload_ids & new_upload_ids)
      { uploads: uploads, changed: difference.any? }
    end

    def update_uploads(upload_info)
      return unless upload_info[:changed]

      DB.exec("DELETE FROM chat_uploads WHERE chat_message_id = #{@chat_message.id}")
      UploadReference.where(target_id: @chat_message).destroy_all
      @chat_message.attach_uploads(upload_info[:uploads])
    end

    def save_revision!
      @chat_message.revisions.create!(
        old_message: @old_message_content,
        new_message: @chat_message.message,
        user_id: @user.id,
      )
    end
  end
end
