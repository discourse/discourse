class TopicListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :more_topics_url,
             :draft,
             :draft_key,
             :draft_sequence

  has_many :topics, serializer: TopicListItemSerializer, embed: :objects, include: true

  def can_create_topic
    scope.can_create?(Topic)
  end

  def filter(keys)
    unless object.more_topics_url.present? && (object.topics.size == SiteSetting.topics_per_page)
      keys.delete(:more_topics_url)
    end
    super(keys)
  end

end
