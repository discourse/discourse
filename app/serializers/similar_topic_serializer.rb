class SimilarTopicSerializer < ApplicationSerializer

  has_one :topic, serializer: TopicListItemSerializer, embed: :ids
  attributes :id, :blurb, :created_at

  def id
    object.topic.id
  end

  def blurb
    object.blurb
  end

  def created_at
    object.topic.created_at
  end
end
