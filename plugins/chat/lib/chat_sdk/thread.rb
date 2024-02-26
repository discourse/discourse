# frozen_string_literal: true

module ChatSDK
  class Thread
    include Chat::WithServiceHelper

    # Updates the title of a specified chat thread.
    #
    # @param title [String] The new title for the chat thread.
    # @param thread_id [Integer] The ID of the chat thread to be updated.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @return [Chat::Thread] The updated thread object with the new title.
    #
    # @example Updating the title of a chat thread
    #   ChatSDK::Thread.update_title(title: "New Thread Title", thread_id: 1, guardian: Guardian.new)
    def self.update_title(**params)
      new.update(title: params[:title], thread_id: params[:thread_id], guardian: params[:guardian])
    end

    def self.update(**params)
      new.update(**params)
    end

    # Retrieves messages from a specified thread.
    #
    # @param thread_id [Integer] The ID of the chat thread from which to fetch messages.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @return [Array<Chat::Message>] An array of message objects from the specified thread.
    #
    # @example Fetching messages from a thread with additional parameters
    #   ChatSDK::Thread.messages(thread_id: 1, guardian: Guardian.new)
    #
    def self.messages(thread_id:, guardian:, **params)
      new.messages(thread_id: thread_id, guardian: guardian, **params)
    end

    def messages(thread_id:, guardian:, **params)
      with_service(
        Chat::ListChannelThreadMessages,
        thread_id: thread_id,
        guardian: guardian,
        **params,
        direction: "future",
      ) do
        on_success { result.messages }
        on_failed_policy(:can_view_thread) { raise "Guardian can't view thread" }
        on_failed_policy(:target_message_exists) { raise "Target message doesn't exist" }
        on_failed_policy(:ensure_thread_enabled) do
          raise "Threading is not enabled for this channel"
        end
        on_failure { raise "Unexpected error" }
      end
    end

    def update(**params)
      with_service(Chat::UpdateThread, **params) do
        on_model_not_found(:channel) do
          raise "Couldn’t find channel with id: `#{params[:channel_id]}`"
        end
        on_model_not_found(:thread) do
          raise "Couldn’t find thread with id: `#{params[:thread_id]}`"
        end
        on_failed_policy(:can_view_channel) { raise "Guardian can't view channel" }
        on_failed_policy(:can_edit_thread) { raise "Guardian can't edit thread" }
        on_failed_policy(:threading_enabled_for_channel) do
          raise "Threading is not enabled for this channel"
        end
        on_failed_contract { |contract| raise contract.errors.full_messages.join(", ") }
        on_success { result.thread_instance }
        on_failure { raise "Unexpected error" }
      end
    end
  end
end
