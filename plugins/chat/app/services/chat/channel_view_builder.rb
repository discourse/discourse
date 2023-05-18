# frozen_string_literal: true

module Chat
  # Builds up a Chat::View object for a channel, and handles several
  # different querying scenraios:
  #
  # * Fetching messages before and after a specific target_message_id
  # * Fetching channel and/or thread tracking state
  # * Fetching threads for the found messages
  # * Fetching an overview of unread threads for the channel
  #
  # @example
  #  Chat::ChannelViewBuilder.call(channel_id: 2, guardian: guardian)
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
    step :fetch_messages
    step :fetch_thread_tracking_overview
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

    def fetch_messages(channel:, guardian:, contract:, **)
      include_thread_messages =
        contract.thread_id.present? || !SiteSetting.enable_experimental_chat_threaded_discussions ||
          !channel.threading_enabled

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

      if messages_data[:target_message]
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
      else
        context.messages = messages_data[:messages]
      end
    end

    def fetch_thread_tracking_overview(guardian:, channel:, **)
      if SiteSetting.enable_experimental_chat_threaded_discussions && channel.threading_enabled
        context.thread_tracking_overview =
          ::Chat::TrackingStateReportQuery
            .call(
              guardian: guardian,
              channel_ids: [channel.id],
              include_threads: true,
              include_zero_unreads: false,
            )
            .find_channel_threads(channel.id)
            .keys
      else
        context.thread_tracking_overview = []
      end
    end

    def fetch_threads_for_messages(guardian:, messages:, channel:, **)
      if SiteSetting.enable_experimental_chat_threaded_discussions && channel.threading_enabled
        context.threads =
          ::Chat::Thread.includes(original_message_user: :user_status).where(
            id: messages.map(&:thread_id).compact.uniq,
          )
      else
        context.threads = []
      end
    end

    def fetch_tracking(guardian:, messages:, channel:, **)
      if SiteSetting.enable_experimental_chat_threaded_discussions && channel.threading_enabled
        context.tracking =
          ::Chat::TrackingStateReportQuery.call(
            guardian: guardian,
            thread_ids: messages.map(&:thread_id).compact.uniq,
            include_threads: true,
          )
      else
        context.tracking = {}
      end
    end

    def build_view(
      guardian:,
      channel:,
      messages:,
      threads:,
      tracking:,
      thread_tracking_overview:,
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
          thread_tracking_overview: thread_tracking_overview,
          threads: threads,
          tracking: tracking,
        )
    end
  end
end
