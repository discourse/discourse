# frozen_string_literal: true

module Chat
  # Gets a list of messages for a channel, with a default
  # page size to limit results.
  #
  # A lookup_message_id can be provided, and by default messages
  # chronologically before and after this message will be loaded,
  # with a limit in both directions.
  #
  # A direction (PAST|FUTURE) can also optionally be specified
  # to load messages only before or after the lookup_message_id.
  #
  # Additionally, messages that are replies to threads are not
  # loaded by default, only if the thread_id is provided.
  #
  # @example
  #  Chat::LookupChannelMessages.call(channel_id: 2, guardian: guardian)
  #
  class LookupChannelMessages
    include Service::Base

    PAST_MESSAGE_LIMIT = 20
    FUTURE_MESSAGE_LIMIT = 20
    PAST = "past"
    FUTURE = "future"
    VALID_DIRECTIONS = [PAST, FUTURE]

    # @!method call(channel_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :channel
    policy :can_view_channel
    step :determine_include_thread_messages
    model :lookup_message
    model :messages
    step :fetch_past_messages
    step :fetch_future_messages
    model :resolved_messages
    step :determine_can_load_more

    class Contract
      attribute :channel_id, :integer

      # TODO (martin) HMMMMMM in some cases we don't have this, what do we do
      # with all the fetching then?
      attribute :lookup_message_id, :integer
      attribute :thread_id, :integer
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

    def determine_include_thread_messages(channel:, contract:, **)
      context.include_thread_messages =
        contract.thread_id.present? || !SiteSetting.enable_experimental_chat_threaded_discussions ||
          !channel.threading_enabled
    end

    def fetch_lookup_message(contract:, channel:, **)
      messages_base_query(channel: channel).with_deleted.find_by(id: contract.lookup_message_id)
    end

    def fetch_messages(guardian:, channel:, contract:, include_thread_messages:, **)
      messages = messages_base_query(channel: channel)
      messages = messages.with_deleted if guardian.can_moderate_chat?(channel.chatable)
      messages = messages.where(thread_id: contract.thread_id) if contract.thread_id.present?
      messages = exclude_thread_messages(channel, messages) if !include_thread_messages
      messages
    end

    def fetch_past_messages(messages:, lookup_message:, **)
      context.past_messages =
        messages
          .where("created_at < ?", lookup_message.created_at)
          .order(created_at: :desc)
          .limit(PAST_MESSAGE_LIMIT)
    end

    def fetch_future_messages(messages:, lookup_message:, **)
      context.future_messages =
        messages
          .where("created_at > ?", lookup_message.created_at)
          .order(created_at: :asc)
          .limit(FUTURE_MESSAGE_LIMIT)
    end

    def determine_can_load_more(past_messages:, future_messages:, **)
      context.can_load_more_past = past_messages.count == PAST_MESSAGE_LIMIT
      context.can_load_more_future = future_messages.count == FUTURE_MESSAGE_LIMIT
    end

    def fetch_resolved_messages(
      past_messages:,
      lookup_message:,
      future_messages:,
      include_thread_messages:,
      **
    )
      lookup_message =
        !include_thread_messages && lookup_message.thread_reply? ? [] : [lookup_message]
      [past_messages.reverse, lookup_message, future_messages].reduce([], :concat)
    end

    def messages_base_query(channel:, **)
      query =
        Chat::Message
          .includes(in_reply_to: [:user, chat_webhook_event: [:incoming_chat_webhook]])
          .includes(:revisions)
          .includes(user: :primary_group)
          .includes(chat_webhook_event: :incoming_chat_webhook)
          .includes(reactions: :user)
          .includes(:bookmarks)
          .includes(:uploads)
          .includes(chat_channel: :chatable)
          .includes(:thread)
          .where(chat_channel_id: channel.id)

      query = query.includes(user: :user_status) if SiteSetting.enable_user_status

      query
    end

    def exclude_thread_messages(channel, messages)
      messages.where(<<~SQL, channel_id: channel.id)
        chat_messages.thread_id IS NULL OR chat_messages.id IN (
          SELECT original_message_id
          FROM chat_threads
          WHERE chat_threads.channel_id = :channel_id
        )
      SQL
    end
  end
end
