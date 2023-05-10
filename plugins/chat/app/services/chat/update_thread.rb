# frozen_string_literal: true

module Chat
  # Updates a thread. The thread_id and channel_id must
  # match. For now we do not want to allow updating threads if the
  # enable_experimental_chat_threaded_discussions hidden site setting
  # is not turned on, and the channel must specifically have threading
  # enabled.
  #
  # Only the thread title can be updated.
  #
  # @example
  #  Chat::UpdateThread.call(thread_id: 88, channel_id: 2, guardian: guardian, title: "Restaurant for Saturday")
  #
  class UpdateThread
    include Service::Base

    # @!method call(thread_id:, channel_id:, guardian:, **params_to_edit)
    #   @param [Integer] thread_id
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @option params_to_edit [String,nil] title
    #   @return [Service::Base::Context]

    policy :threaded_discussions_enabled
    contract
    model :thread, :fetch_thread
    policy :can_view_channel
    policy :can_edit_thread
    policy :threading_enabled_for_channel
    step :update
    step :publish_metadata

    # @!visibility private
    class Contract
      attribute :thread_id, :integer
      attribute :channel_id, :integer
      attribute :title, :string

      validates :thread_id, :channel_id, presence: true
      validates :title, length: { maximum: Chat::Thread::MAX_TITLE_LENGTH }
    end

    private

    def threaded_discussions_enabled
      SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def fetch_thread(contract:, **)
      Chat::Thread.find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def can_view_channel(guardian:, thread:, **)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def can_edit_thread(guardian:, thread:, **)
      guardian.can_edit_thread?(thread)
    end

    def threading_enabled_for_channel(thread:, **)
      thread.channel.threading_enabled
    end

    def update(thread:, contract:, **)
      thread.update(title: contract.title)
      fail!(thread.errors.full_messages.join(", ")) if thread.invalid?
    end

    def publish_metadata(thread:, **)
      Chat::Publisher.publish_thread_original_message_metadata!(thread)
    end
  end
end
