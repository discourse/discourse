module TopicTagsMixin
  def self.included(klass)
    klass.attributes :tags
  end

  def include_tags?
    scope.can_see_tags?(topic)
  end

  def tags
    topic.tags.pluck(:name)
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end
end
