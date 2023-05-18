# frozen_string_literal: true

module Chat
  class MessagesQuery
    PAST_MESSAGE_LIMIT = 20
    FUTURE_MESSAGE_LIMIT = 20
    PAST = "past"
    FUTURE = "future"
    VALID_DIRECTIONS = [PAST, FUTURE]

    def self.call(
      channel:,
      guardian:,
      thread_id: nil,
      lookup_message_id: nil,
      include_thread_messages: false,
      page_size: PAST_MESSAGE_LIMIT + FUTURE_MESSAGE_LIMIT,
      direction: nil
    )
      if lookup_message_id.present?
        lookup_message = base_query(channel: channel).with_deleted.find_by(id: lookup_message_id)
      end

      messages = base_query(channel: channel)
      messages = messages.with_deleted if guardian.can_moderate_chat?(channel.chatable)
      messages = messages.where(thread_id: thread_id) if thread_id.present?
      messages = messages.where(<<~SQL, channel_id: channel.id) if !include_thread_messages
        chat_messages.thread_id IS NULL OR chat_messages.id IN (
          SELECT original_message_id
          FROM chat_threads
          WHERE chat_threads.channel_id = :channel_id
        )
      SQL

      if lookup_message
        past_messages =
          messages
            .where("created_at < ?", lookup_message.created_at)
            .order(created_at: :desc)
            .limit(PAST_MESSAGE_LIMIT)
      end

      if lookup_message
        future_messages =
          messages
            .where("created_at > ?", lookup_message.created_at)
            .order(created_at: :asc)
            .limit(FUTURE_MESSAGE_LIMIT)
      end

      if !lookup_message
        order = direction == FUTURE ? "ASC" : "DESC"
        messages = messages.order("created_at #{order}, id #{order}").limit(page_size).to_a
      end

      if lookup_message
        can_load_more_past = past_messages.count == PAST_MESSAGE_LIMIT
        can_load_more_future = future_messages.count == FUTURE_MESSAGE_LIMIT
      elsif direction == FUTURE
        can_load_more_future = messages.size == page_size
      elsif direction == PAST
        can_load_more_past = messages.size == page_size
      else
        # When direction is blank, we'll return the latest messages.
        can_load_more_future = false
        can_load_more_past = messages.size == page_size
      end

      if lookup_message
        {
          past_messages: past_messages,
          future_messages: future_messages,
          lookup_message: lookup_message,
          can_load_more_past: can_load_more_past,
          can_load_more_future: can_load_more_future,
        }
      else
        {
          messages: direction == FUTURE ? messages : messages.reverse,
          can_load_more_past: can_load_more_past,
          can_load_more_future: can_load_more_future,
        }
      end
    end

    def self.base_query(channel:)
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
  end
end
