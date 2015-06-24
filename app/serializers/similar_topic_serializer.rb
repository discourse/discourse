class SimilarTopicSerializer < ApplicationSerializer

  has_one :topic, serializer: TopicListItemSerializer, embed: :ids
  attributes :id, :blurb, :created_at, :url

  def id
    object.topic.id
  end

  def blurb
    object.blurb
  end

  def url
    object.topic.url
  end

  def created_at
    object.topic.created_at
  end
end
