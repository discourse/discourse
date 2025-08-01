# frozen_string_literal: true

module Chat
  # List messages of a thread before and after a specific target (id, date),
  # or fetching paginated messages from last read.
  #
  # @example
  #  Chat::ListThreadMessages.call(params: { thread_id: 2, **optional_params }, guardian: guardian)
  #
  class ListChannelThreadMessages
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :thread_id
    #   @return [Service::Base::Context]

    params do
      attribute :thread_id, :integer
      # If this is not present, then we just fetch messages with page_size
      # and direction.
      attribute :target_message_id, :integer # (optional)
      attribute :direction, :string # (optional)
      attribute :page_size, :integer # (optional)
      attribute :fetch_from_last_read, :boolean # (optional)
      attribute :fetch_from_last_message, :boolean # (optional)
      attribute :fetch_from_first_message, :boolean # (optional)
      attribute :target_date, :string # (optional)

      validates :thread_id, presence: true
      validates :page_size,
                numericality: {
                  less_than_or_equal_to: Chat::MessagesQuery::MAX_PAGE_SIZE,
                  greater_than_or_equal_to: 1,
                  only_integer: true,
                  only_numeric: true,
                },
                allow_nil: true
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true

      after_validation { self.page_size ||= Chat::MessagesQuery::MAX_PAGE_SIZE }

      def include_target_message_id
        fetch_from_first_message || fetch_from_last_message
      end
    end

    model :thread
    policy :can_view_thread
    model :membership, optional: true
    model :target_message_id, optional: true
    policy :target_message_exists, class_name: Chat::Thread::Policy::MessageExistence
    model :metadata, optional: true
    model :messages, optional: true

    private

    def fetch_thread(params:)
      ::Chat::Thread.strict_loading.includes(channel: :chatable).find_by(id: params.thread_id)
    end

    def can_view_thread(guardian:, thread:)
      guardian.user == Discourse.system_user || guardian.can_preview_chat_channel?(thread.channel)
    end

    def fetch_membership(thread:, guardian:)
      thread.membership_for(guardian.user)
    end

    def fetch_target_message_id(params:, membership:, thread:)
      if params.fetch_from_last_message
        thread.last_message_id
      elsif params.fetch_from_first_message
        thread.original_message_id
      elsif params.fetch_from_last_read || !params.target_message_id
        membership&.last_read_message_id
      elsif params.target_message_id
        params.target_message_id
      end
    end

    def fetch_metadata(thread:, guardian:, params:, target_message_id:)
      ::Chat::MessagesQuery.call(
        guardian:,
        target_message_id:,
        channel: thread.channel,
        thread_id: thread.id,
        include_target_message_id: params.include_target_message_id,
        **params.slice(:page_size, :direction, :target_date),
      )
    end

    def fetch_messages(metadata:)
      [
        metadata[:messages],
        metadata[:past_messages]&.reverse,
        metadata[:target_message],
        metadata[:future_messages],
      ].flatten.compact
    end
  end
end
