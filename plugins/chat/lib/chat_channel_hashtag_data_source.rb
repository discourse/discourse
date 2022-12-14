# frozen_string_literal: true

class Chat::ChatChannelHashtagDataSource
  def self.icon
    "comment"
  end

  def self.channel_to_hashtag_item(guardian, channel)
    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = channel.title
      item.description = channel.description
      item.slug = channel.slug
      item.icon = icon
      item.relative_url = channel.relative_url
      item.type = "channel"
    end
  end

  def self.lookup(guardian, slugs)
    if SiteSetting.enable_experimental_hashtag_autocomplete
      return [] if !guardian.can_chat?
      Chat::ChatChannelFetcher
        .secured_public_channel_slug_lookup(guardian, slugs)
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    else
      []
    end
  end

  def self.search(guardian, term, limit)
    if SiteSetting.enable_experimental_hashtag_autocomplete
      return [] if !guardian.can_chat?
      Chat::ChatChannelFetcher
        .secured_public_channel_search(
          guardian,
          filter: term,
          limit: limit,
          exclude_dm_channels: true,
        )
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    else
      []
    end
  end

  def self.search_sort(search_results, _)
    search_results.sort_by { |result| result.text.downcase }
  end

  def self.search_without_term(guardian, limit)
    if SiteSetting.enable_experimental_hashtag_autocomplete
      return [] if !guardian.can_chat?
      allowed_channel_ids_sql =
        Chat::ChatChannelFetcher.generate_allowed_channel_ids_sql(
          guardian,
          exclude_dm_channels: true,
        )
      ChatChannel
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
    else
      []
    end
  end
end
