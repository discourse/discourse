# frozen_string_literal: true

module Chat
  # Service responsible to search messages in channels.
  #
  # @example
  #  ::Chat::SearchMessage.call(
  #    guardian: guardian,
  #    params: {
  #      query: "foo",
  #      channel_id: 1,
  #    }
  #  )
  #
  class SearchMessage
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :query The query used to query the results
    #   @option params [Integer] :channel_id ID of the channel to scope the search
    #   @option params [Boolean] :exclude_threads Whether to exclude thread messages (keeps original thread messages)
    #   @return [Service::Base::Context]

    def self.advanced_filter(trigger, &block)
      advanced_filters[trigger] = block
    end

    def self.advanced_filters
      @advanced_filters ||= {}
    end

    advanced_filter(/\A\@(\S+)\z/i) do |messages, match|
      username = User.normalize_username(match)
      user_id = User.not_staged.where(username_lower: username).pick(:id)
      user_id = @guardian.user&.id if !user_id && username == "me"

      if user_id
        messages.where(user_id: user_id)
      else
        messages.where("1 = 0")
      end
    end

    params do
      attribute :query, :string, default: ""
      attribute :channel_id, :integer
      attribute :limit, :integer, default: 20
      attribute :exclude_threads, :boolean, default: false

      validates :limit, numericality: { in: 1..40 }
    end

    model :channel, optional: true
    policy :can_view_channel
    model :messages, optional: true

    private

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params.channel_id) if params.channel_id
    end

    def can_view_channel(guardian:, channel:)
      channel ? guardian.can_preview_chat_channel?(channel) : true
    end

    def fetch_messages(params:, guardian:, channel:)
      return ::Chat::Message.none if params.query.blank?

      @guardian = guardian
      cleaned_query = Search.clean_term(params.query)
      processed_query = process_advanced_search!(cleaned_query)

      messages = ::Chat::Message.joins(:chat_channel)

      if channel
        messages = messages.where("chat_channels.id IN (?)", channel.id)
      else
        messages =
          messages.where(
            "chat_channels.id IN (?)",
            ChannelFetcher.all_secured_channel_ids(guardian),
          )
      end

      messages = apply_filters(messages)
      messages = apply_thread_exclusion(messages, params.exclude_threads)

      if processed_query.present?
        prepared_query = Search.prepare_data(processed_query)
        ts_config = Search.ts_config
        ts_query = Search.ts_query(term: prepared_query, ts_config: ts_config)
        messages =
          messages.joins(:message_search_data).where(
            "chat_message_search_data.search_data @@ #{ts_query}",
          )
      elsif @filters.blank?
        return ::Chat::Message.none
      end

      messages.order(created_at: :desc).limit(params.limit)
    end

    private

    def process_advanced_search!(query)
      query
        .to_s
        .split(/\s+/)
        .map do |word|
          next if word.blank?

          found = false

          self.class.advanced_filters.each do |matcher, block|
            if word =~ matcher
              (@filters ||= []) << [block, $1]
              found = true
              break
            end
          end

          found ? nil : word
        end
        .compact
        .join(" ")
    end

    def apply_filters(messages)
      @filters&.each do |block, match|
        if block.arity == 1
          messages = instance_exec(messages, &block) || messages
        else
          messages = instance_exec(messages, match, &block) || messages
        end
      end

      messages
    end

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
  end
end
