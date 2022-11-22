# frozen_string_literal: true

class Chat::ChatChannelHashtagDataSource
  def self.icon
    "comment"
  end

  def self.channel_to_hashtag_item(guardian, channel)
    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = channel.title(guardian.user)
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

  def self.search(guardian, term, limit, exact_match: false)
    if SiteSetting.enable_experimental_hashtag_autocomplete
      results =
        if exact_match
          lookup(guardian, term)
        else
          Chat::ChatChannelFetcher
            .secured_public_channel_search(
              guardian,
              filter: term,
              limit: limit,
              exclude_dm_channels: true,
            )
            .map { |channel| channel_to_hashtag_item(guardian, channel) }
        end
    else
      []
    end
  end
end
