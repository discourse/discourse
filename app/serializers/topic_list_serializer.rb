class TopicListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :more_topics_url,
             :draft,
             :draft_key,
             :draft_sequence,
             :for_period,
             :per_page,
             :top_tags,
             :tags,
             :shared_drafts

  has_many :topics, serializer: TopicListItemSerializer, embed: :objects
  has_many :shared_drafts, serializer: TopicListItemSerializer, embed: :objects
  has_many :tags, serializer: TagSerializer, embed: :objects

  def can_create_topic
    scope.can_create?(Topic)
  end

  def include_shared_drafts?
    object.shared_drafts.present?
  end

  def include_for_period?
    for_period.present?
  end

  def include_more_topics_url?
    object.more_topics_url.present? && (object.topics.size == object.per_page)
  end

  def include_top_tags?
    Tag.include_tags?
  end

  def include_tags?
    SiteSetting.tagging_enabled && object.tags.present?
  end
end
