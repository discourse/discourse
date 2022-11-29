# frozen_string_literal: true

class Chat::ChatChannelHashtagDataSource
  def self.icon
    "comment"
  end

  def self.channel_to_hashtag_item(guardian, channel)
    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = channel.title(guardian.user)
      item.description = channel.description
      item.slug = channel.slug
      item.icon = icon
      item.relative_url = channel.relative_url
      item.type = "channel"
    end
  end

  def self.lookup(guardian, slugs)
    if SiteSetting.enable_experimental_hashtag_autocomplete
      Chat::ChatChannelFetcher
        .secured_public_channel_slug_lookup(guardian, slugs)
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    else
      []
    end
  end

  def self.search(guardian, term, limit)
    if SiteSetting.enable_experimental_hashtag_autocomplete
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
      allowed_channel_ids_sql =
        Chat::ChatChannelFetcher.generate_allowed_channel_ids_sql(
          guardian,
          exclude_dm_channels: true,
        )
      channel_ids = DB.query(<<~SQL, limit: limit).map(&:chat_channel_id)
        SELECT chat_channel_id, MAX(chat_messages.created_at)
        FROM chat_messages
        INNER JOIN chat_channels ON chat_messages.chat_channel_id = chat_channels.id
        WHERE chat_messages.deleted_at IS NULL
          AND chat_channels.deleted_at IS NULL
          AND chat_channel_id IN (#{allowed_channel_ids_sql})
          AND chat_messages.created_at > (NOW() - INTERVAL '2 WEEKS')
        GROUP BY chat_channel_id
        ORDER BY MAX(chat_messages.created_at) DESC
        LIMIT :limit
      SQL
      ChatChannel
        .where(id: channel_ids)
        .map { |channel| channel_to_hashtag_item(guardian, channel) }
    else
      []
    end
  end
end
