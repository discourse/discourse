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

  def tags
    all_tags.map { |tag| { id: tag.id, name: localized_tag_name(tag), slug: tag.slug } }
  end

  def tags_descriptions
    all_tags
      .each
      .with_object({}) do |tag, acc|
        acc[localized_tag_name(tag)] = localized_tag_description(tag)&.truncate(DESCRIPTION_LIMIT)
      end
      .compact
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end

  private

  def localized_tag_name(tag)
    if ContentLocalization.show_translated_tag?(tag, scope)
      tag.get_localization&.name || tag.name
    else
      tag.name
    end
  end

  def localized_tag_description(tag)
    if ContentLocalization.show_translated_tag?(tag, scope)
      tag.get_localization&.description || tag.description
    else
      tag.description
    end
  end

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
