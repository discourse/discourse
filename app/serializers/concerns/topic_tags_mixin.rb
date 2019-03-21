module TopicTagsMixin
  def self.included(klass)
    klass.attributes :tags
  end

  def include_tags?
    scope.can_see_tags?(topic)
  end

  def tags
    # Calling method `pluck` along with `includes` causing N+1 queries
    tags = topic.tags.map(&:name)

    scope.is_staff? ? tags : tags - scope.hidden_tag_names
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end
end
