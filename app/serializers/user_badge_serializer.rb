class UserBadgeSerializer < ApplicationSerializer

  class UserSerializer < BasicUserSerializer
    include UserPrimaryGroupMixin

    attributes :name,
               :moderator,
               :admin
  end

  attributes :id, :granted_at, :count, :post_id, :post_number

  has_one :badge
  has_one :user, serializer: UserSerializer, root: :users
  has_one :granted_by, serializer: UserSerializer, root: :users
  has_one :topic, serializer: BasicTopicSerializer

  def include_count?
    object.respond_to? :count
  end

  def include_post_id?
    object.badge.show_posts && object.post_id && object.post
  end

  alias :include_topic? :include_post_id?
  alias :include_post_number? :include_post_id?

  def post_number
    object.post && object.post.post_number
  end

  def topic
    object.post.topic
  end
end
