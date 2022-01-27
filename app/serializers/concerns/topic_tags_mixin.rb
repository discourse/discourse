# frozen_string_literal: true

module TopicTagsMixin
  def self.included(klass)
    klass.attributes :tags
    klass.attributes :tags_descriptions
  end

  def include_tags?
    scope.can_see_tags?(topic)
  end

  def tags
    all_tags.map(&:name)
  end

  def tags_descriptions
    all_tags.each.with_object({}) { |tag, acc| acc[tag.name] = tag.description }.compact
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end

  private

  def all_tags
    return @tags if defined?(@tags)
    # Calling method `pluck` or `order` along with `includes` causing N+1 queries
    tags = (SiteSetting.tags_sort_alphabetically ? topic.tags.sort_by(&:name) : topic.tags.sort_by(&:topic_count).reverse)
    if !scope.is_staff?
      tags = tags.reject { |tag| scope.hidden_tag_names.include?(tag[:name]) }
    end
    @tags = tags
  end
end
