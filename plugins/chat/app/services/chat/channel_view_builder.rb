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
    #   @option optional_params [Boolean] fetch_from_last_read
    #   @option optional_params [Integer] page_size
    #   @option optional_params [String] direction
    #   @return [Service::Base::Context]

    contract
    model :channel
    policy :can_view_channel
    step :determine_target_message_id
    policy :target_message_exists
    step :determine_threads_enabled
    step :determine_include_thread_messages
    step :fetch_messages
    step :fetch_unread_thread_overview
    step :fetch_threads_for_messages
    step :fetch_tracking
    step :fetch_thread_memberships
    step :fetch_thread_participants
    step :update_channel_last_viewed_at
    step :build_view

    class Contract
      attribute :channel_id, :integer

      # If this is not present, then we just fetch messages with page_size
      # and direction.
      attribute :target_message_id, :integer # (optional)
      attribute :thread_id, :integer # (optional)
      attribute :direction, :string # (optional)
      attribute :page_size, :integer # (optional)
      attribute :fetch_from_last_read, :boolean # (optional)
      attribute :target_date, :string # (optional)

      validates :channel_id, presence: true
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true
      validates :page_size,
                numericality: {
                  less_than_or_equal_to: Chat::MessagesQuery::MAX_PAGE_SIZE,
                  only_integer: true,
                },
                allow_nil: true

      validate :page_size_present, if: -> { target_message_id.blank? && !fetch_from_last_read }

      def page_size_present
        errors.add(:page_size, :blank) if page_size.blank?
      end
    end

    private

    def fetch_channel(contract:, **)
      Chat::Channel.includes(:chatable, :last_message).find_by(id: contract.channel_id)
    end

    def can_view_channel(guardian:, channel:, **)
      guardian.can_preview_chat_channel?(channel)
    end

    def determine_target_message_id(contract:, channel:, guardian:, **)
      if contract.fetch_from_last_read
        contract.target_message_id = channel.membership_for(guardian.user)&.last_read_message_id

        # We need to force a page size here because we don't want to
        # load all messages in the channel (since starting from 0
        # makes them all unread). When the target_message_id is provided
        # page size is not required since we load N messages either side of
        # the target.
        if contract.target_message_id.blank?
          contract.page_size = contract.page_size || Chat::MessagesQuery::MAX_PAGE_SIZE
        end
      end
    end

    def target_message_exists(contract:, guardian:, **)
      return true if contract.target_message_id.blank?
      target_message =
        Chat::Message.with_deleted.find_by(
          id: contract.target_message_id,
          chat_channel_id: contract.channel_id,
        )
      return false if target_message.blank?
      return true if !target_message.trashed?
      target_message.user_id == guardian.user.id || guardian.is_staff?
    end

    def determine_threads_enabled(channel:, **)
      context.threads_enabled = channel.threading_enabled
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
          target_date: contract.target_date,
        )

      context.can_load_more_past = messages_data[:can_load_more_past]
      context.can_load_more_future = messages_data[:can_load_more_future]

      if !messages_data[:target_message] && !messages_data[:target_date]
        context.messages = messages_data[:messages]
      else
        messages_data[:target_message] = (
          if !include_thread_messages && messages_data[:target_message]&.thread_reply?
            []
          else
            [messages_data[:target_message]]
          end
        )

        context.messages = [
          messages_data[:past_messages].reverse,
          messages_data[:target_message],
          messages_data[:future_messages],
        ].reduce([], :concat).compact
      end
    end

    # The thread tracking overview is a simple array of hashes consisting
    # of thread IDs that have unread messages as well as the datetime of the
    # last reply in the thread.
    #
    # Only threads with unread messages will be included in this array.
    # This is a low-cost way to know how many threads the user has unread
    # across the entire channel.
    def fetch_unread_thread_overview(guardian:, channel:, threads_enabled:, **)
      if !threads_enabled
        context.unread_thread_overview = {}
      else
        context.unread_thread_overview =
          ::Chat::TrackingStateReportQuery.call(
            guardian: guardian,
            channel_ids: [channel.id],
            include_threads: true,
            include_read: false,
            include_last_reply_details: true,
          ).find_channel_thread_overviews(channel.id)
      end
    end

    def fetch_threads_for_messages(guardian:, messages:, channel:, threads_enabled:, **)
      if !threads_enabled
        context.threads = []
      else
        context.threads =
          ::Chat::Thread
            .strict_loading
            .includes(last_message: %i[user uploads], original_message_user: :user_status)
            .where(id: messages.map(&:thread_id).compact.uniq)

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

    def fetch_thread_memberships(threads:, guardian:, **)
      if threads.empty?
        context.thread_memberships = []
      else
        context.thread_memberships =
          ::Chat::UserChatThreadMembership.where(
            thread_id: threads.map(&:id),
            user_id: guardian.user.id,
          )
      end
    end

    def fetch_thread_participants(threads:, **)
      context.thread_participants =
        ::Chat::ThreadParticipantQuery.call(thread_ids: threads.map(&:id))
    end

    def update_channel_last_viewed_at(channel:, guardian:, **)
      channel.membership_for(guardian.user)&.update!(last_viewed_at: Time.zone.now)
    end

    def build_view(
      guardian:,
      channel:,
      messages:,
      threads:,
      tracking:,
      unread_thread_overview:,
      can_load_more_past:,
      can_load_more_future:,
      thread_memberships:,
      thread_participants:,
      **
    )
      context.view =
        Chat::View.new(
          chat_channel: channel,
          chat_messages: messages,
          user: guardian.user,
          can_load_more_past: can_load_more_past,
          can_load_more_future: can_load_more_future,
          unread_thread_overview: unread_thread_overview,
          threads: threads,
          tracking: tracking,
          thread_memberships: thread_memberships,
          thread_participants: thread_participants,
        )
    end
  end
end
