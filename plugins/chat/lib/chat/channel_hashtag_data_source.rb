# frozen_string_literal: true

module Chat
  class ChannelHashtagDataSource
    def self.enabled?
      SiteSetting.enable_public_channels
    end

    def self.icon
      "comment"
    end

    def self.type
      "channel"
    end

    def self.channel_to_hashtag_item(guardian, channel)
      HashtagAutocompleteService::HashtagItem.new.tap do |item|
        item.text = channel.title
        item.description = channel.description
        item.slug = channel.slug
        item.icon = icon
        item.relative_url = channel.relative_url
        item.type = "channel"
        item.id = channel.id
      end
    end

    def self.lookup(guardian, slugs)
      return [] if !guardian.can_chat?
      Chat::ChannelFetcher
        .secured_public_channel_slug_lookup(guardian, slugs)
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    end

    def self.search(
      guardian,
      term,
      limit,
      condition = HashtagAutocompleteService.search_conditions[:contains]
    )
      return [] if !guardian.can_chat?
      Chat::ChannelFetcher
        .secured_public_channel_search(
          guardian,
          filter: term,
          limit: limit,
          exclude_dm_channels: true,
          match_filter_on_starts_with:
            condition == HashtagAutocompleteService.search_conditions[:starts_with],
        )
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    end

    def self.search_sort(search_results, _)
      search_results.sort_by { |result| result.text.downcase }
    end

    def self.search_without_term(guardian, limit)
      return [] if !guardian.can_chat?
      allowed_channel_ids_sql =
        Chat::ChannelFetcher.generate_allowed_channel_ids_sql(guardian, exclude_dm_channels: true)
      Chat::Channel
        .joins(
          "INNER JOIN user_chat_channel_memberships
            ON user_chat_channel_memberships.chat_channel_id = chat_channels.id
            AND user_chat_channel_memberships.user_id = #{guardian.user.id}
            AND user_chat_channel_memberships.following = true",
        )
        .where("chat_channels.id IN (#{allowed_channel_ids_sql})")
        .order(messages_count: :desc)
        .limit(limit)
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    end
  end
end
