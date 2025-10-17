# frozen_string_literal: true

module Chat
  module Action
    module SearchMessage
      # Applies filtering and sorting to chat messages search results.
      #
      # Handles two types of operations:
      # 1. Thread exclusion - Filters out thread reply messages while preserving
      #    messages that are not part of threads and original thread starter messages
      # 2. Sorting - Orders messages by relevance (default) or latest (created_at desc)
      #
      # Returns the modified ActiveRecord::Relation with filters and sorting applied.
      class ApplyFiltersAndSorting < Service::ActionBase
        # @param [ActiveRecord::Relation] messages The messages relation to filter and sort
        # @param [Boolean] exclude_threads Whether to exclude thread reply messages
        # @param [String] sort The sort option ("relevance" or "latest")
        option :messages
        option :exclude_threads
        option :sort

        def call
          filtered_messages = apply_thread_exclusion(messages, exclude_threads)
          apply_sorting(filtered_messages, sort)
        end

        private

        # Applies thread exclusion filtering to messages when requested.
        #
        # When exclude_threads is true, this method filters out thread reply messages
        # while preserving:
        # 1. Messages that are not part of any thread (thread_id IS NULL)
        # 2. Original messages that started threads (these have thread_id but are
        #    referenced as original_message_id in the chat_threads table)
        #
        # This allows searching in channel messages and thread starters without
        # getting overwhelmed by thread replies.
        #
        # @param [ActiveRecord::Relation] messages The messages query to filter
        # @param [Boolean] exclude_threads Whether to apply thread exclusion
        # @return [ActiveRecord::Relation] The filtered messages query
        def apply_thread_exclusion(messages, exclude_threads)
          return messages unless exclude_threads

          # Exclude messages that have a thread_id unless they are the original message of the thread
          messages.where(
            "chat_messages.thread_id IS NULL OR chat_messages.id IN (
              SELECT ct.original_message_id
              FROM chat_threads ct
              WHERE ct.id = chat_messages.thread_id
            )",
          )
        end

        # Applies sorting to messages based on the specified sort option.
        #
        # @param [ActiveRecord::Relation] messages The messages query to sort
        # @param [String] sort The sort option ("relevance" or "latest")
        # @return [ActiveRecord::Relation] The sorted messages query
        def apply_sorting(messages, sort)
          case sort
          when "latest"
            messages.order(created_at: :desc)
          else
            messages
          end
        end
      end
    end
  end
end
