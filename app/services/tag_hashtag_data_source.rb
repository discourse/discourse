# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide tag
# results when looking up a tag slug via markdown or searching for
# tags via the # autocomplete character.
class TagHashtagDataSource
  def self.icon
    "tag"
  end

  def self.type
    "tag"
  end

  def self.tag_to_hashtag_item(tag, guardian)
    topic_count_column = Tag.topic_count_column(guardian)

    tag =
      Tag.new(
        tag.slice(:id, :name, :description).merge(topic_count_column => tag[:count]),
      ) if tag.is_a?(Hash)

    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = tag.name
      item.secondary_text = "x#{tag.public_send(topic_count_column)}"
      item.description = tag.description
      item.slug = tag.name
      item.relative_url = tag.url
      item.icon = icon
    end
  end
  private_class_method :tag_to_hashtag_item

  def self.lookup(guardian, slugs)
    return [] if !SiteSetting.tagging_enabled
    DiscourseTagging
      .filter_visible(Tag.where_name(slugs), guardian)
      .map { |tag| tag_to_hashtag_item(tag, guardian) }
  end

  def self.search(
    guardian,
    term,
    limit,
    condition = HashtagAutocompleteService.search_conditions[:contains]
  )
    return [] if !SiteSetting.tagging_enabled

    tags_with_counts, _ =
      DiscourseTagging.filter_allowed_tags(
        guardian,
        term: term,
        term_type:
          (
            if condition == HashtagAutocompleteService.search_conditions[:starts_with]
              DiscourseTagging.term_types[:starts_with]
            else
              DiscourseTagging.term_types[:contains]
            end
          ),
        with_context: true,
        limit: limit,
        order_search_results: true,
      )

    TagsController
      .tag_counts_json(tags_with_counts, guardian)
      .take(limit)
      .map { |tag| tag_to_hashtag_item(tag, guardian) }
  end

  def self.search_sort(search_results, _)
    search_results.sort_by { |item| item.text.downcase }
  end

  def self.search_without_term(guardian, limit)
    return [] if !SiteSetting.tagging_enabled

    tags_with_counts, _ =
      DiscourseTagging.filter_allowed_tags(
        guardian,
        with_context: true,
        limit: limit,
        order_popularity: true,
        excluded_tag_names: DiscourseTagging.muted_tags(guardian.user),
      )

    TagsController
      .tag_counts_json(tags_with_counts, guardian)
      .take(limit)
      .map { |tag| tag_to_hashtag_item(tag, guardian) }
  end
end
