# frozen_string_literal: true

class Chat::Action::SearchForMessages < Service::ActionBase
  option :guardian
  option :params
  option :channel

  delegate :offset, :limit, :query, :exclude_threads, :sort, to: :params, private: true
  delegate :processed_query, :filters, to: :search_query_result, private: true

  def call
    return default_metadata if processed_query.blank? && filters.blank?

    # Fetch one extra to check if there are more results
    messages = sorted_and_filtered_messages.offset(offset).limit(limit + 1).to_a
    default_metadata.merge(messages: messages.take(limit), has_more: messages.size > limit)
  end

  private

  def default_metadata
    { limit:, offset:, has_more: false, messages: [] }
  end

  def search_query_result
    @search_query_result ||=
      Chat::Action::SearchMessage::ProcessSearchQuery.call(
        query:,
        guardian:,
        messages:
          Chat::Message.joins(:chat_channel).where(
            chat_channels: {
              id: channel || Chat::ChannelFetcher.all_secured_channel_ids(guardian),
            },
          ),
      )
  end

  def sorted_and_filtered_messages
    @sorted_and_filtered_messages ||=
      Chat::Action::SearchMessage::ApplyFiltersAndSorting.call(
        exclude_threads:,
        sort:,
        messages: search_query_result.messages,
      )
  end
end
