# frozen_string_literal: true

module Chat
  # Builds up a Chat::View object for a channel, and handles several
  # different querying scenraios:
  #
  # * Fetching messages before and after a specific lookup_message_id
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
    #   @option optional_params [String] direction
    #   @option optional_params [Integer] thread_id
    #   @option optional_params [Integer] lookup_message_id
    #   @return [Service::Base::Context]

    contract
    model :channel
    policy :can_view_channel
    model :messages
    step :fetch_thread_tracking_overview
    step :fetch_threads_for_messages
    step :fetch_tracking
    step :build_view

    class Contract
      attribute :channel_id, :integer

      # TODO (martin) HMMMMMM in some cases we don't have this, what do we do
      # with all the fetching then?
      attribute :lookup_message_id, :integer # (optional)
      attribute :thread_id, :integer # (optional)

      # attribute :page_size, :integer, default: PAST_MESSAGE_LIMIT + FUTURE_MESSAGE_LIMIT
      # attribute :direction, :string

      validates :channel_id, presence: true
      # validates :direction, inclusion: { in: VALID_DIRECTIONS }, allow_nil: true
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
          lookup_message_id: contract.lookup_message_id,
          thread_id: contract.thread_id,
          include_thread_messages: include_thread_messages,
        )

      messages_data[:lookup_message] = (
        if !include_thread_messages && messages_data[:lookup_message].thread_reply?
          []
        else
          [messages_data[:lookup_message]]
        end
      )

      context.can_load_more_past = messages_data[:can_load_more_past]
      context.can_load_more_future = messages_data[:can_load_more_future]

      [
        messages_data[:past_messages].reverse,
        messages_data[:lookup_message],
        messages_data[:future_messages],
      ].reduce([], :concat)
    end

    def fetch_thread_tracking_overview(guardian:, channel:, **)
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
    end

    def fetch_threads_for_messages(guardian:, messages:, channel:, **)
      context.threads =
        ::Chat::Thread.includes(original_message_user: :user_status).where(
          id: messages.map(&:thread_id).compact.uniq,
        )
    end

    def fetch_tracking(guardian:, messages:, channel:, **)
      context.tracking =
        ::Chat::TrackingStateReportQuery.call(
          guardian: guardian,
          thread_ids: messages.map(&:thread_id).compact.uniq,
          include_threads: true,
        )
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
