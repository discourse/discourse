# frozen_string_literal: true

module Chat
  # Service responsible for updating a message.
  #
  # @example
  #  Chat::UpdateMessage.call(message_id: 2, guardian: guardian, message: "A new message")
  #
  class UpdateMessage
    include Service::Base

    # @!method call(message_id:, guardian:, message:, upload_ids:)
    #   @param guardian [Guardian]
    #   @param message_id [Integer]
    #   @param message [String]
    #   @param upload_ids [Array<Integer>] IDs of uploaded documents

    options do
      attribute :strip_whitespaces, :boolean, default: true
      attribute :process_inline, :boolean, default: -> { Rails.env.test? }
    end

    contract do
      attribute :message_id, :string
      attribute :message, :string
      attribute :upload_ids, :array

      validates :message_id, presence: true
      validates :message, presence: true, if: -> { upload_ids.blank? }
    end
    model :message
    model :uploads, optional: true
    step :enforce_membership
    model :membership
    policy :can_modify_channel_message
    policy :can_modify_message
    step :clean_message
    transaction do
      step :modify_message
      step :update_excerpt
      step :save_message
      step :save_revision
      step :publish
    end

    private

    def enforce_membership(guardian:, message:)
      message.chat_channel.add(guardian.user) if guardian.user.bot?
    end

    def fetch_message(contract:)
      ::Chat::Message.includes(
        :chat_mentions,
        :bookmarks,
        :chat_webhook_event,
        :uploads,
        :revisions,
        reactions: [:user],
        thread: [:channel, last_message: [:user]],
        chat_channel: [
          :last_message,
          :chat_channel_archive,
          chatable: [:topic_only_relative_url, direct_message_users: [user: :user_option]],
        ],
        user: :user_status,
      ).find_by(id: contract.message_id)
    end

    def fetch_membership(guardian:, message:)
      message.chat_channel.membership_for(guardian.user)
    end

    def fetch_uploads(contract:, guardian:)
      return if !SiteSetting.chat_allow_uploads
      guardian.user.uploads.where(id: contract.upload_ids)
    end

    def can_modify_channel_message(guardian:, message:)
      guardian.can_modify_channel_message?(message.chat_channel)
    end

    def can_modify_message(guardian:, message:)
      guardian.can_edit_chat?(message)
    end

    def clean_message(contract:, options:)
      contract.message =
        TextCleaner.clean(
          contract.message,
          strip_zero_width_spaces: true,
          strip_whitespaces: options.strip_whitespaces,
        )
    end

    def modify_message(contract:, message:, guardian:, uploads:)
      message.message = contract.message
      message.last_editor_id = guardian.user.id
      message.cook

      return if uploads&.size != contract.upload_ids.to_a.size

      new_upload_ids = uploads.map(&:id)
      existing_upload_ids = message.upload_ids
      difference = (existing_upload_ids + new_upload_ids) - (existing_upload_ids & new_upload_ids)
      return if !difference.any?

      message.upload_ids = new_upload_ids
    end

    def update_excerpt(message:)
      message.excerpt = message.build_excerpt
    end

    def save_message(message:)
      message.save!
    end

    def save_revision(message:, guardian:)
      return false if message.streaming_before_last_save

      prev_message = message.message_before_last_save || message.message_was
      return if !should_create_revision(message, prev_message, guardian)

      context[:revision] = message.revisions.create!(
        old_message: prev_message,
        new_message: message.message,
        user_id: guardian.user.id,
      )
    end

    def should_create_revision(new_message, prev_message, guardian)
      max_seconds = SiteSetting.chat_editing_grace_period
      seconds_since_created = Time.now.to_i - new_message&.created_at&.iso8601&.to_time.to_i
      return true if seconds_since_created > max_seconds

      max_edited_chars =
        (
          if guardian.user.has_trust_level?(TrustLevel[2])
            SiteSetting.chat_editing_grace_period_max_diff_high_trust
          else
            SiteSetting.chat_editing_grace_period_max_diff_low_trust
          end
        )
      chars_edited =
        ONPDiff
          .new(prev_message, new_message.message)
          .short_diff
          .sum { |str, type| type == :common ? 0 : str.size }

      chars_edited > max_edited_chars
    end

    def publish(message:, guardian:, contract:, options:)
      edit_timestamp = context[:revision]&.created_at&.iso8601(6) || Time.zone.now.iso8601(6)

      ::Chat::Publisher.publish_edit!(message.chat_channel, message)

      DiscourseEvent.trigger(:chat_message_edited, message, message.chat_channel, message.user)

      if options.process_inline
        Jobs::Chat::ProcessMessage.new.execute(
          { chat_message_id: message.id, edit_timestamp: edit_timestamp },
        )
      else
        Jobs.enqueue(
          Jobs::Chat::ProcessMessage,
          { chat_message_id: message.id, edit_timestamp: edit_timestamp },
        )
      end

      if message.thread.present?
        ::Chat::Publisher.publish_thread_original_message_metadata!(message.thread)
      end
    end
  end
end
