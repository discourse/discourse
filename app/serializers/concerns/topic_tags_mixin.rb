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

    if scope.is_staff?
      tags
    else
      tags - (@options[:hidden_tag_names] || hidden_tag_names)
    end
  end

  def topic
    object.is_a?(Topic) ? object : object.topic
  end

  private

  def hidden_tag_names
    @hidden_tag_names ||= DiscourseTagging.hidden_tag_names(scope)
  end
end
