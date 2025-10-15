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
  #      sort: "latest",
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
    #   @option params [Integer] :limit Maximum number of results to return (1-40, defaults to 20)
    #   @option params [Integer] :offset Number of results to skip for pagination (defaults to 0)
    #   @option params [Boolean] :exclude_threads Whether to exclude thread messages (keeps original thread messages)
    #   @option params [String] :sort Sort order for results ("relevance" or "latest", defaults to "relevance")
    #   @return [Service::Base::Context]

    params do
      attribute :query, :string
      attribute :channel_id, :integer
      attribute :limit, :integer, default: 20
      attribute :offset, :integer, default: 0
      attribute :exclude_threads, :boolean, default: false
      attribute :sort, :string, default: "relevance"

      validates :query, presence: true
      validates :limit, numericality: { in: 1..40 }
      validates :offset, numericality: { greater_than_or_equal_to: 0 }
      validates :sort, inclusion: { in: %w[relevance latest] }
    end

    only_if(:provided_channel_id) do
      model :channel
      policy :can_view_channel
    end

    model :messages, optional: true

    private

    def provided_channel_id(params:)
      params.channel_id.present?
    end

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params.channel_id)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_messages(params:, guardian:)
      messages = ::Chat::Message.joins(:chat_channel)

      if context[:channel]
        messages = messages.where("chat_channels.id IN (?)", context[:channel].id)
      else
        messages =
          messages.where(
            "chat_channels.id IN (?)",
            ChannelFetcher.all_secured_channel_ids(guardian),
          )
      end

      result =
        Chat::Action::SearchMessage::ProcessSearchQuery.call(
          query: Search.clean_term(params.query),
          messages:,
          guardian:,
        )

      messages = result.messages

      if result.processed_query.present?
        prepared_query = Search.prepare_data(result.processed_query)
        ts_config = Search.ts_config
        ts_query = Search.ts_query(term: prepared_query, ts_config: ts_config)
        messages =
          messages.joins(:message_search_data).where(
            "chat_message_search_data.search_data @@ #{ts_query}",
          )
      elsif result.filters.blank?
        return ::Chat::Message.none
      end

      messages =
        Chat::Action::SearchMessage::ApplyFiltersAndSorting.call(
          messages:,
          exclude_threads: params.exclude_threads,
          sort: params.sort,
        )

      # Fetch one extra to check if there are more results
      results = messages.offset(params.offset).limit(params.limit + 1).to_a

      context[:has_more] = results.size > params.limit

      results.take(params.limit)
    end
  end
end
