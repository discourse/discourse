# frozen_string_literal: true

module Chat
  # Service responsible for creating a new message.
  #
  # @example
  #  Chat::CreateMessage.call(params: { chat_channel_id: 2, message: "A new message" }, guardian: guardian)
  #
  class CreateMessage
    include Service::Base

    # @!method self.call(guardian:, params:, options:)
    #   @param guardian [Guardian]
    #   @param [Hash] params
    #   @option params [Integer] :chat_channel_id
    #   @option params [String] :message
    #   @option params [Integer] :in_reply_to_id ID of a message to reply to
    #   @option params [Integer] :thread_id ID of a thread to reply to
    #   @option params [Array<Integer>] :upload_ids IDs of uploaded documents
    #   @option params [Integer] :context_topic_id ID of the currently visible topic in drawer mode
    #   @option params [Array<Integer>] :context_post_ids IDs of the currently visible posts in drawer mode
    #   @option params [String] :staged_id arbitrary string that will be sent back to the client
    #   @param [Hash] options
    #   @option options [Chat::IncomingWebhook] :incoming_chat_webhook
    #   @return [Service::Base::Context]

    options do
      attribute :streaming, :boolean, default: false
      attribute :enforce_membership, :boolean, default: false
      attribute :process_inline, :boolean, default: -> { Rails.env.test? }
      attribute :force_thread, :boolean, default: false
      attribute :strip_whitespaces, :boolean, default: true
      attribute :created_by_sdk, :boolean, default: false
    end

    policy :no_silenced_user
    params do
      attribute :chat_channel_id, :string
      attribute :in_reply_to_id, :string
      attribute :context_topic_id, :integer
      attribute :context_post_ids, :array
      attribute :message, :string
      attribute :staged_id, :string
      attribute :upload_ids, :array
      attribute :thread_id, :string

      validates :chat_channel_id, presence: true
      validates :message, presence: true, if: -> { upload_ids.blank? }

      after_validation do
        next if message.blank?
        self.message =
          TextCleaner.clean(
            message,
            strip_whitespaces: options.strip_whitespaces,
            strip_zero_width_spaces: true,
          )
      end
    end
    model :channel
    step :enforce_membership
    model :membership
    policy :allowed_to_create_message_in_channel, class_name: Chat::Channel::Policy::MessageCreation
    model :reply, optional: true
    policy :ensure_reply_consistency
    model :thread, optional: true
    policy :ensure_valid_thread_for_channel
    policy :ensure_thread_matches_parent
    model :uploads, optional: true
    model :message_instance, :instantiate_message
    transaction do
      step :create_excerpt
      step :update_created_by_sdk
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

    private

    def no_silenced_user(guardian:)
      !guardian.is_silenced?
    end

    def fetch_channel(params:)
      Chat::Channel.find_by_id_or_slug(params.chat_channel_id)
    end

    def enforce_membership(guardian:, channel:, options:)
      if guardian.user.bot? || options.enforce_membership
        channel.add(guardian.user)

        if channel.direct_message_channel?
          channel.chatable.direct_message_users.find_or_create_by!(user: guardian.user)
        end
      end
    end

    def fetch_membership(guardian:, channel:)
      channel.membership_for(guardian.user)
    end

    def fetch_reply(params:)
      Chat::Message.find_by(id: params.in_reply_to_id)
    end

    def ensure_reply_consistency(channel:, params:, reply:)
      return true if params.in_reply_to_id.blank?
      reply&.chat_channel == channel
    end

    def fetch_thread(params:, reply:, channel:, options:)
      return Chat::Thread.find_by(id: params.thread_id) if params.thread_id.present?
      return unless reply
      reply.thread ||
        reply.build_thread(
          original_message: reply,
          original_message_user: reply.user,
          channel: channel,
          force: options.force_thread,
        )
    end

    def ensure_valid_thread_for_channel(thread:, params:, channel:)
      return true if params.thread_id.blank?
      thread&.channel == channel
    end

    def ensure_thread_matches_parent(thread:, reply:)
      return true unless thread && reply
      reply.thread == thread
    end

    def fetch_uploads(params:, guardian:)
      return [] if !SiteSetting.chat_allow_uploads
      guardian.user.uploads.where(id: params.upload_ids)
    end

    def instantiate_message(channel:, guardian:, params:, uploads:, thread:, reply:, options:)
      channel.chat_messages.new(
        user: guardian.user,
        last_editor: guardian.user,
        in_reply_to: reply,
        message: params.message,
        uploads: uploads,
        thread: thread,
        cooked: ::Chat::Message.cook(params.message, user_id: guardian.user.id),
        cooked_version: ::Chat::Message::BAKED_VERSION,
        streaming: options.streaming,
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

    def create_webhook_event(message_instance:)
      return if context[:incoming_chat_webhook].blank?
      message_instance.create_chat_webhook_event(
        incoming_chat_webhook: context[:incoming_chat_webhook],
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

    def update_created_by_sdk(message_instance:, options:)
      message_instance.created_by_sdk = options.created_by_sdk
    end

    def process_direct_message_channel(membership:)
      Chat::Action::PublishAndFollowDirectMessageChannel.call(channel_membership: membership)
    end

    def publish_new_thread(reply:, channel:, thread:)
      return unless channel.threading_enabled? || thread&.force
      return unless reply&.thread_id_previously_changed?(from: nil)
      Chat::Publisher.publish_thread_created!(channel, reply, thread.id)
    end

    def process(channel:, message_instance:, params:, thread:, options:)
      ::Chat::Publisher.publish_new!(channel, message_instance, params.staged_id)

      DiscourseEvent.trigger(
        :chat_message_created,
        message_instance,
        channel,
        message_instance.user,
        {
          thread: thread,
          thread_replies_count: thread&.replies_count_cache || 0,
          context: {
            post_ids: params.context_post_ids,
            topic_id: params.context_topic_id,
          },
        },
      )

      if options.process_inline
        Jobs::Chat::ProcessMessage.new.execute(
          { chat_message_id: message_instance.id, staged_id: params.staged_id },
        )
      else
        Jobs.enqueue(
          Jobs::Chat::ProcessMessage,
          { chat_message_id: message_instance.id, staged_id: params.staged_id },
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
