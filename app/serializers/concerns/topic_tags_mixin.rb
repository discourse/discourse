# frozen_string_literal: true

module TopicTagsMixin
  DESCRIPTION_LIMIT = 80

  def self.included(klass)
    klass.attributes :tags
    klass.attributes :tags_descriptions
  end

  def include_tags?
    scope.can_see_tags?(topic)
  end

  def include_tags_descriptions?
    include_tags?
  end

  def tags
    all_tags.map do |tag|
      display_name = tag.display_name(scope)

      {
        id: tag.id,
        name: display_name,
        slug: tag.slug_for_url,
        original_name: (tag.name if display_name != tag.name),
      }.compact
    end
  end

  def tags_descriptions
    all_tags
      .each
      .with_object({}) do |tag, acc|
        acc[tag.display_name(scope)] = tag.display_description(scope)&.truncate(DESCRIPTION_LIMIT)
      end
      .compact
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end

  private

  def all_tags
    return @tags if defined?(@tags)

    tags = topic.visible_tags(scope)

    # Calling method `pluck` or `order` along with `includes` causing N+1 queries
    tags =
      (
        if SiteSetting.tags_sort_alphabetically
          tags.sort_by(&:name)
        else
          topic_count_column = Tag.topic_count_column(scope)
          tags.sort_by { |tag| tag.public_send(topic_count_column) }.reverse
        end
      )

    @tags = tags
  end
end
