# frozen_string_literal: true

module Chat
  # Builds up a Chat::View object for a channel, and handles several
  # different querying scenraios:
  #
  # * Fetching messages before and after a specific target_message_id,
  #   or fetching paginated messages.
  # * Fetching threads for the found messages.
  # * Fetching thread tracking state.
  # * Fetching an overview of unread threads for the channel.
  #
  # @example
  #  Chat::ChannelViewBuilder.call(channel_id: 2, guardian: guardian, **optional_params)
  #
  class ChannelViewBuilder
    include Service::Base

    # @!method call(channel_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @option optional_params [Integer] thread_id
    #   @option optional_params [Integer] target_message_id
    #   @option optional_params [Integer] page_size
    #   @option optional_params [String] direction
    #   @return [Service::Base::Context]

    contract
    model :channel
    policy :can_view_channel
    policy :target_message_exists
    step :determine_threads_enabled
    step :determine_include_thread_messages
    step :fetch_messages
    step :fetch_unread_thread_ids
    step :fetch_threads_for_messages
    step :fetch_tracking
    step :build_view

    class Contract
      attribute :channel_id, :integer

      # If this is not present, then we just fetch messages with page_size
      # and direction.
      attribute :target_message_id, :integer # (optional)
      attribute :thread_id, :integer # (optional)
      attribute :direction, :string # (optional)
      attribute :page_size, :integer # (optional)

      validates :channel_id, presence: true
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true
    end

    private

    def fetch_channel(contract:, **)
      Chat::Channel.includes(:chatable).find_by(id: contract.channel_id)
    end

    def can_view_channel(guardian:, channel:, **)
      guardian.can_preview_chat_channel?(channel)
    end

    def target_message_exists(contract:, guardian:, **)
      return true if contract.target_message_id.blank?
      target_message = Chat::Message.unscoped.find_by(id: contract.target_message_id)
      return false if target_message.blank?
      return true if !target_message.trashed?
      target_message.user_id == guardian.user.id || guardian.is_staff?
    end

    def determine_threads_enabled(channel:, **)
      context.threads_enabled =
        SiteSetting.enable_experimental_chat_threaded_discussions && channel.threading_enabled
    end

    def determine_include_thread_messages(contract:, threads_enabled:, **)
      context.include_thread_messages = contract.thread_id.present? || !threads_enabled
    end

    def fetch_messages(channel:, guardian:, contract:, include_thread_messages:, **)
      messages_data =
        ::Chat::MessagesQuery.call(
          channel: channel,
          guardian: guardian,
          target_message_id: contract.target_message_id,
          thread_id: contract.thread_id,
          include_thread_messages: include_thread_messages,
          page_size: contract.page_size,
          direction: contract.direction,
        )

      context.can_load_more_past = messages_data[:can_load_more_past]
      context.can_load_more_future = messages_data[:can_load_more_future]

      if !messages_data[:target_message]
        context.messages = messages_data[:messages]
      else
        messages_data[:target_message] = (
          if !include_thread_messages && messages_data[:target_message].thread_reply?
            []
          else
            [messages_data[:target_message]]
          end
        )

        context.messages = [
          messages_data[:past_messages].reverse,
          messages_data[:target_message],
          messages_data[:future_messages],
        ].reduce([], :concat)
      end
    end

    # The thread tracking overview is a simple array of thread IDs
    # that have unread messages, only threads with unread messages
    # will be included in this array. This is a low-cost way to know
    # how many threads the user has unread across the entire channel.
    def fetch_unread_thread_ids(guardian:, channel:, threads_enabled:, **)
      if !threads_enabled
        context.unread_thread_ids = []
      else
        context.unread_thread_ids =
          ::Chat::TrackingStateReportQuery
            .call(
              guardian: guardian,
              channel_ids: [channel.id],
              include_threads: true,
              include_read: false,
            )
            .find_channel_threads(channel.id)
            .keys
      end
    end

    def fetch_threads_for_messages(guardian:, messages:, channel:, threads_enabled:, **)
      if !threads_enabled
        context.threads = []
      else
        context.threads =
          ::Chat::Thread.includes(original_message_user: :user_status).where(
            id: messages.map(&:thread_id).compact.uniq,
          )

        # Saves us having to load the same message we already have.
        context.threads.each do |thread|
          thread.original_message =
            messages.find { |message| message.id == thread.original_message_id }
        end
      end
    end

    # Only thread tracking is necessary to fetch here -- we preload
    # channel tracking state for all the current user's tracked channels
    # in the CurrentUserSerializer.
    def fetch_tracking(guardian:, messages:, channel:, threads_enabled:, **)
      thread_ids = messages.map(&:thread_id).compact.uniq
      if !threads_enabled || thread_ids.empty?
        context.tracking = {}
      else
        context.tracking =
          ::Chat::TrackingStateReportQuery.call(
            guardian: guardian,
            thread_ids: thread_ids,
            include_threads: true,
          )
      end
    end

    def build_view(
      guardian:,
      channel:,
      messages:,
      threads:,
      tracking:,
      unread_thread_ids:,
      can_load_more_past:,
      can_load_more_future:,
      **
    )
      context.view =
        Chat::View.new(
          chat_channel: channel,
          chat_messages: messages,
          user: guardian.user,
          can_load_more_past: can_load_more_past,
          can_load_more_future: can_load_more_future,
          unread_thread_ids: unread_thread_ids,
          threads: threads,
          tracking: tracking,
        )
    end
  end
end
