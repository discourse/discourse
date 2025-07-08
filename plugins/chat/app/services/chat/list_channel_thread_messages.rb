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
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true
      validates :page_size, numericality: { only_integer: true }, allow_nil: true
    end

    model :thread
    policy :can_view_thread
    model :membership, optional: true
    step :determine_target_message_id
    policy :target_message_exists
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

    def determine_target_message_id(params:, membership:, guardian:, thread:)
      if params.fetch_from_last_message
        context[:target_message_id] = thread.last_message_id
      elsif params.fetch_from_first_message
        context[:target_message_id] = thread.original_message_id
      elsif params.fetch_from_last_read || !params.target_message_id
        context[:target_message_id] = membership&.last_read_message_id
      elsif params.target_message_id
        context[:target_message_id] = params.target_message_id
      end
    end

    def target_message_exists(params:, guardian:)
      return true if context.target_message_id.blank?
      target_message =
        ::Chat::Message.with_deleted.find_by(
          id: context.target_message_id,
          thread_id: params.thread_id,
        )
      return false if target_message.blank?
      return true if !target_message.trashed?
      target_message.user_id == guardian.user.id || guardian.is_staff?
    end

    def fetch_metadata(thread:, guardian:, params:)
      ::Chat::MessagesQuery.call(
        guardian:,
        channel: thread.channel,
        target_message_id: context.target_message_id,
        thread_id: thread.id,
        page_size: params.page_size,
        direction: params.direction,
        target_date: params.target_date,
        include_target_message_id:
          params.fetch_from_first_message || params.fetch_from_last_message,
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
