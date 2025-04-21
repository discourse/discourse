# frozen_string_literal: true

module Chat
  # Creates a thread.
  #
  # @example
  #  Chat::CreateThread.call(guardian: guardian, params: { channel_id: 2, original_message_id: 3, title: "Restaurant for Saturday" })
  #
  class CreateThread
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :original_message_id
    #   @option params [Integer] :channel_id
    #   @option params [String,nil] :title
    #   @return [Service::Base::Context]

    params do
      attribute :original_message_id, :integer
      attribute :channel_id, :integer
      attribute :title, :string

      validates :original_message_id, :channel_id, presence: true
      validates :title, length: { maximum: Chat::Thread::MAX_TITLE_LENGTH }
    end

    model :channel
    policy :can_view_channel
    policy :threading_enabled_for_channel
    model :original_message

    transaction do
      model :thread, :find_or_create_thread
      step :associate_thread_to_message
    end

    step :publish_new_thread
    step :trigger_chat_thread_created_event

    private

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params.channel_id)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def threading_enabled_for_channel(channel:)
      channel.threading_enabled?
    end

    def fetch_original_message(channel:, params:)
      ::Chat::Message.find_by(id: params.original_message_id, chat_channel_id: params.channel_id)
    end

    def find_or_create_thread(channel:, original_message:, params:)
      return original_message.thread if original_message.thread

      channel.threads.create(
        title: params.title,
        original_message: original_message,
        original_message_user: original_message.user,
      )
    end

    def associate_thread_to_message(original_message:, thread:)
      original_message.update(thread:)
    end

    def publish_new_thread(channel:, original_message:, thread:)
      ::Chat::Publisher.publish_thread_created!(channel, original_message, thread.id)
    end

    def trigger_chat_thread_created_event(thread:)
      ::DiscourseEvent.trigger(:chat_thread_created, thread)
    end
  end
end
