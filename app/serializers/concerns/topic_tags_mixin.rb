module TopicTagsMixin
  def self.included(klass)
    klass.attributes :tags
  end

  def include_tags?
    scope.can_see_tags?(topic)
  end

  def tags
    # Calling method `pluck` along with `includes` causing N+1 queries
    DiscourseTagging.filter_visible(topic.tags, scope).map(&:name)
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end
end
