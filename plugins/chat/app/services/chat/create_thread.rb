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

    contract do
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
      step :find_or_create_thread
      step :associate_thread_to_message
      step :fetch_membership
      step :publish_new_thread
      step :trigger_chat_thread_created_event
    end

    private

    def fetch_channel(contract:)
      ::Chat::Channel.find_by(id: contract.channel_id)
    end

    def fetch_original_message(channel:, contract:)
      ::Chat::Message.find_by(
        id: contract.original_message_id,
        chat_channel_id: contract.channel_id,
      )
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def threading_enabled_for_channel(channel:)
      channel.threading_enabled
    end

    def find_or_create_thread(channel:, original_message:, contract:)
      if original_message.thread_id.present?
        return context[:thread] = ::Chat::Thread.find_by(id: original_message.thread_id)
      end

      context[:thread] = channel.threads.create(
        title: contract.title,
        original_message: original_message,
        original_message_user: original_message.user,
      )
      fail!(context.thread.errors.full_messages.join(", ")) if context.thread.invalid?
    end

    def associate_thread_to_message(original_message:)
      original_message.update(thread: context.thread)
    end

    def fetch_membership(guardian:)
      context[:membership] = context.thread.membership_for(guardian.user)
    end

    def publish_new_thread(channel:, original_message:)
      ::Chat::Publisher.publish_thread_created!(channel, original_message, context.thread.id)
    end

    def trigger_chat_thread_created_event
      ::DiscourseEvent.trigger(:chat_thread_created, context.thread)
    end
  end
end
