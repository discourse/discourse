# frozen_string_literal: true

module Chat
  # Service responsible for creating a new message.
  #
  # @example
  #  Chat::CreateMessage.call(chat_channel_id: 2, guardian: guardian, message: "A new message")
  #
  class CreateMessage
    include Service::Base

    # @!method call(chat_channel_id:, guardian:, in_reply_to_id:, message:, staged_id:, upload_ids:, thread_id:, incoming_chat_webhook:)
    #   @param guardian [Guardian]
    #   @param chat_channel_id [Integer]
    #   @param message [String]
    #   @param in_reply_to_id [Integer] ID of a message to reply to
    #   @param thread_id [Integer] ID of a thread to reply to
    #   @param upload_ids [Array<Integer>] IDs of uploaded documents
    #   @param context_topic_id [Integer] ID of the currently visible topic in drawer mode
    #   @param context_post_ids [Array<Integer>] IDs of the currently visible posts in drawer mode
    #   @param staged_id [String] arbitrary string that will be sent back to the client
    #   @param incoming_chat_webhook [Chat::IncomingWebhook]

    policy :no_silenced_user
    contract
    model :channel
    step :enforce_membership
    model :membership
    policy :allowed_to_create_message_in_channel, class_name: Chat::Channel::MessageCreationPolicy
    model :reply, optional: true
    policy :ensure_reply_consistency
    model :thread, optional: true
    policy :ensure_valid_thread_for_channel
    policy :ensure_thread_matches_parent
    model :uploads, optional: true
    step :clean_message
    model :message_instance, :instantiate_message

    transaction do
      step :create_excerpt
      step :save_message
      step :delete_drafts
      step :post_process_thread
      step :create_webhook_event
      step :update_channel_last_message
      step :update_membership_last_read
      step :process_direct_message_channel
    end
    step :publish_new_thread
    step :process
    step :publish_user_tracking_state

    class Contract
      attribute :chat_channel_id, :string
      attribute :in_reply_to_id, :string
      attribute :context_topic_id, :integer
      attribute :context_post_ids, :array
      attribute :message, :string
      attribute :staged_id, :string
      attribute :upload_ids, :array
      attribute :thread_id, :string
      attribute :streaming, :boolean, default: false
      attribute :enforce_membership, :boolean, default: false
      attribute :incoming_chat_webhook
      attribute :process_inline, :boolean, default: Rails.env.test?
      attribute :force_thread, :boolean, default: false
      attribute :strip_whitespaces, :boolean, default: true

      validates :chat_channel_id, presence: true
      validates :message, presence: true, if: -> { upload_ids.blank? }
    end

    private

    def no_silenced_user(guardian:)
      !guardian.is_silenced?
    end

    def fetch_channel(contract:)
      Chat::Channel.find_by_id_or_slug(contract.chat_channel_id)
    end

    def enforce_membership(guardian:, channel:, contract:)
      if guardian.user.bot? || contract.enforce_membership
        channel.add(guardian.user)

        if channel.direct_message_channel?
          channel.chatable.direct_message_users.find_or_create_by!(user: guardian.user)
        end
      end
    end

    def fetch_membership(guardian:, channel:)
      channel.membership_for(guardian.user)
    end

    def fetch_reply(contract:)
      Chat::Message.find_by(id: contract.in_reply_to_id)
    end

    def ensure_reply_consistency(channel:, contract:, reply:)
      return true if contract.in_reply_to_id.blank?
      reply&.chat_channel == channel
    end

    def fetch_thread(contract:, reply:, channel:)
      return Chat::Thread.find_by(id: contract.thread_id) if contract.thread_id.present?
      return unless reply
      reply.thread ||
        reply.build_thread(
          original_message: reply,
          original_message_user: reply.user,
          channel: channel,
          force: contract.force_thread,
        )
    end

    def ensure_valid_thread_for_channel(thread:, contract:, channel:)
      return true if contract.thread_id.blank?
      thread&.channel == channel
    end

    def ensure_thread_matches_parent(thread:, reply:)
      return true unless thread && reply
      reply.thread == thread
    end

    def fetch_uploads(contract:, guardian:)
      return [] if !SiteSetting.chat_allow_uploads
      guardian.user.uploads.where(id: contract.upload_ids)
    end

    def clean_message(contract:)
      contract.message =
        TextCleaner.clean(
          contract.message,
          strip_whitespaces: contract.strip_whitespaces,
          strip_zero_width_spaces: true,
        )
    end

    def instantiate_message(channel:, guardian:, contract:, uploads:, thread:, reply:)
      channel.chat_messages.new(
        user: guardian.user,
        last_editor: guardian.user,
        in_reply_to: reply,
        message: contract.message,
        uploads: uploads,
        thread: thread,
        cooked: ::Chat::Message.cook(contract.message, user_id: guardian.user.id),
        cooked_version: ::Chat::Message::BAKED_VERSION,
        streaming: contract.streaming,
      )
    end

    def save_message(message_instance:)
      message_instance.save!
    end

    def delete_drafts(channel:, guardian:)
      Chat::Draft.where(user: guardian.user, chat_channel: channel).destroy_all
    end

    def post_process_thread(thread:, message_instance:, guardian:)
      return unless thread

      thread.update!(last_message: message_instance)
      thread.increment_replies_count_cache
      thread.add(guardian.user).update!(last_read_message: message_instance)
      thread.add(thread.original_message_user)
    end

    def create_webhook_event(contract:, message_instance:)
      return if contract.incoming_chat_webhook.blank?
      message_instance.create_chat_webhook_event(
        incoming_chat_webhook: contract.incoming_chat_webhook,
      )
    end

    def update_channel_last_message(channel:, message_instance:)
      return if message_instance.in_thread?
      channel.update!(last_message: message_instance)
    end

    def update_membership_last_read(membership:, message_instance:)
      return if message_instance.in_thread?
      membership.update!(last_read_message: message_instance)
    end

    def process_direct_message_channel(membership:)
      Chat::Action::PublishAndFollowDirectMessageChannel.call(channel_membership: membership)
    end

    def publish_new_thread(reply:, contract:, channel:, thread:)
      return unless channel.threading_enabled? || thread&.force
      return unless reply&.thread_id_previously_changed?(from: nil)
      Chat::Publisher.publish_thread_created!(channel, reply, thread.id)
    end

    def process(channel:, message_instance:, contract:, thread:)
      ::Chat::Publisher.publish_new!(channel, message_instance, contract.staged_id)

      DiscourseEvent.trigger(
        :chat_message_created,
        message_instance,
        channel,
        message_instance.user,
        {
          thread: thread,
          thread_replies_count: thread&.replies_count_cache || 0,
          context: {
            post_ids: contract.context_post_ids,
            topic_id: contract.context_topic_id,
          },
        },
      )

      if contract.process_inline
        Jobs::Chat::ProcessMessage.new.execute(
          { chat_message_id: message_instance.id, staged_id: contract.staged_id },
        )
      else
        Jobs.enqueue(
          Jobs::Chat::ProcessMessage,
          { chat_message_id: message_instance.id, staged_id: contract.staged_id },
        )
      end
    end

    def create_excerpt(message_instance:)
      message_instance.excerpt = message_instance.build_excerpt
    end

    def publish_user_tracking_state(message_instance:, channel:, membership:, guardian:)
      message_to_publish = message_instance
      message_to_publish =
        membership.last_read_message || message_instance if message_instance.in_thread?
      Chat::Publisher.publish_user_tracking_state!(guardian.user, channel, message_to_publish)
    end
  end
end
