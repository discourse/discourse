# frozen_string_literal: true

module ChatSDK
  class Thread
    # Updates the title of a specified chat thread.
    #
    # @param title [String] The new title for the chat thread.
    # @param thread_id [Integer] The ID of the chat thread to be updated.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @return [Chat::Thread] The updated thread object with the new title.
    #
    # @example Updating the title of a chat thread
    #   ChatSDK::Thread.update_title(title: "New Thread Title", thread_id: 1, guardian: Guardian.new)
    #
    def self.update_title(thread_id:, guardian:, title:)
      new.update(thread_id:, guardian:, title:)
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
    def self.messages(...)
      new.messages(...)
    end

    # Fetches the first messages from a specified chat thread, starting from the first available message.
    #
    # @param thread_id [Integer] The ID of the chat thread from which to fetch messages.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @param page_size [Integer] (optional) The number of messages to fetch, defaults to 10.
    # @return [Array<Chat::Message>] An array of message objects representing the first messages in the thread.
    #
    # @example Fetching the first 15 messages from a thread
    #   ChatSDK::Thread.first_messages(thread_id: 1, guardian: Guardian.new, page_size: 15)
    #
    def self.first_messages(thread_id:, guardian:, page_size: 10)
      new.messages(
        thread_id:,
        guardian:,
        page_size:,
        direction: "future",
        fetch_from_first_message: true,
      )
    end

    # Fetches the last messages from a specified chat thread, starting from the last available message.
    #
    # @param thread_id [Integer] The ID of the chat thread from which to fetch messages.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @param page_size [Integer] (optional) The number of messages to fetch, defaults to 10.
    # @return [Array<Chat::Message>] An array of message objects representing the last messages in the thread.
    #
    # @example Fetching the last 20 messages from a thread
    #   ChatSDK::Thread.last_messages(thread_id: 2, guardian: Guardian.new, page_size: 20)
    #
    def self.last_messages(thread_id:, guardian:, page_size: 10)
      new.messages(
        thread_id:,
        guardian:,
        page_size:,
        direction: "past",
        fetch_from_last_message: true,
      )
    end

    def self.update(...)
      new.update(...)
    end

    def messages(thread_id:, guardian:, direction: "future", **params)
      Chat::ListChannelThreadMessages.call(
        guardian:,
        params: {
          thread_id:,
          direction:,
          **params,
        },
      ) do
        on_success { |messages:| messages }
        on_failed_policy(:can_view_thread) { raise "Guardian can't view thread" }
        on_failed_policy(:target_message_exists) { raise "Target message doesn't exist" }
        on_failure { raise "Unexpected error" }
      end
    end

    def update(guardian:, **params)
      Chat::UpdateThread.call(guardian:, params:) do
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
        on_success { |thread:| thread }
        on_failure { raise "Unexpected error" }
      end
    end
  end
end
