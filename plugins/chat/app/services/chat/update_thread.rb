# frozen_string_literal: true

module Chat
  # Updates a thread. The thread_id and channel_id must
  # match, and the channel must specifically have threading enabled.
  #
  # Only the thread title can be updated.
  #
  # @example
  #  Chat::UpdateThread.call(guardian: guardian, params: { thread_id: 88, title: "Restaurant for Saturday" })
  #
  class UpdateThread
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :thread_id
    #   @option params [Integer] :channel_id
    #   @return [Service::Base::Context]

    params do
      attribute :thread_id, :integer
      attribute :title, :string

      validates :thread_id, presence: true
      validates :title, length: { maximum: Chat::Thread::MAX_TITLE_LENGTH }
    end
    model :thread
    policy :can_view_channel
    policy :can_edit_thread
    policy :threading_enabled_for_channel
    step :update
    step :publish_metadata

    private

    def fetch_thread(params:)
      Chat::Thread.find_by(id: params[:thread_id])
    end

    def can_view_channel(guardian:, thread:)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def can_edit_thread(guardian:, thread:)
      guardian.can_edit_thread?(thread)
    end

    def threading_enabled_for_channel(thread:)
      thread.channel.threading_enabled
    end

    def update(thread:, params:)
      thread.update(params.slice(:title))
      fail!(thread.errors.full_messages.join(", ")) if thread.invalid?
    end

    def publish_metadata(thread:)
      Chat::Publisher.publish_thread_original_message_metadata!(thread)
    end
  end
end
