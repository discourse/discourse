class TopicListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :more_topics_url,
             :draft,
             :draft_key,
             :draft_sequence,
             :for_period,
             :per_page,
             :tags

  has_many :topics, serializer: TopicListItemSerializer, embed: :objects

  def can_create_topic
    scope.can_create?(Topic)
  end

  def include_for_period?
    for_period.present?
  end

  def include_more_topics_url?
    object.more_topics_url.present? && (object.topics.size == object.per_page)
  end

  def include_tags?
    SiteSetting.tagging_enabled && SiteSetting.show_filter_by_tag
  end
  def tags
    Tag.top_tags
  end

end
