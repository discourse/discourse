# frozen_string_literal: true

class TagHashtagDataSource
  def self.lookup(guardian, slugs)
    tag_hashtags = {}
    return tag_hashtags if !SiteSetting.tagging_enabled

    DiscourseTagging
      .filter_visible(Tag.where_name(slugs), guardian)
      .each { |tag| tag_hashtags[tag.name] = tag.full_url }
    tag_hashtags
  end

  def self.search(guardian, term, limit)
    if SiteSetting.tagging_enabled
      tags_with_counts, _ =
        DiscourseTagging.filter_allowed_tags(
          guardian,
          term: term,
          with_context: true,
          limit: limit,
          for_input: true,
        )
      TagsController
        .tag_counts_json(tags_with_counts)
        .take(limit)
        .map do |tag|
          HashtagAutocompleteService::HashtagItem.new.tap do |item|
            item.text = "#{tag[:name]} x #{tag[:count]}"
            item.slug = tag[:name]
            item.icon = "tag"
          end
        end
    else
      []
    end
  end
end
