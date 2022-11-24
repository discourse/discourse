# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide tag
# results when looking up a tag slug via markdown or searching for
# tags via the # autocomplete character.
class TagHashtagDataSource
  def self.icon
    "tag"
  end

  def self.tag_to_hashtag_item(tag, include_count: false)
    tag = Tag.new(tag.slice(:id, :name, :description).merge(topic_count: tag[:count])) if tag.is_a?(
      Hash,
    )

    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      if include_count
        item.text = "#{tag.name} x #{tag.topic_count}"
      else
        item.text = tag.name
      end
      item.description = tag.description
      item.slug = tag.name
      item.relative_url = tag.url
      item.icon = icon
    end
  end

  def self.lookup(guardian, slugs)
    return [] if !SiteSetting.tagging_enabled
    DiscourseTagging
      .filter_visible(Tag.where_name(slugs), guardian)
      .map { |tag| tag_to_hashtag_item(tag) }
  end

  def self.search(guardian, term, limit)
    return [] if !SiteSetting.tagging_enabled

    tags_with_counts, _ =
      DiscourseTagging.filter_allowed_tags(
        guardian,
        term: term,
        with_context: true,
        limit: limit,
        for_input: true,
        order_search_results: true,
      )

    TagsController
      .tag_counts_json(tags_with_counts)
      .take(limit)
      .map { |tag| tag_to_hashtag_item(tag, include_count: true) }
  end
end
