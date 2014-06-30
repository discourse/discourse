class UserBadgeSerializer < ApplicationSerializer
  attributes :id, :granted_at, :count, :post_id

  has_one :badge
  has_one :user, serializer: BasicUserSerializer, root: :users
  has_one :granted_by, serializer: BasicUserSerializer, root: :users
  has_one :topic, serializer: BasicTopicSerializer

  def include_count?
    object.respond_to? :count
  end

  def include_post_id?
    !object.post_id.nil?
  end
  alias :include_topic? :include_post_id?

  def topic
    object.post.topic
  end
end
