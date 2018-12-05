class UserBadgeSerializer < ApplicationSerializer

  class UserSerializer < BasicUserSerializer
    attributes :name,
               :moderator,
               :admin,
               :primary_group_name,
               :primary_group_flair_url,
               :primary_group_flair_bg_color,
               :primary_group_flair_color

    def primary_group_name
      return nil unless object&.primary_group_id
      object&.primary_group&.name
    end

    def primary_group_flair_url
      object&.primary_group&.flair_url
    end

    def primary_group_flair_bg_color
      object&.primary_group&.flair_bg_color
    end

    def primary_group_flair_color
      object&.primary_group&.flair_color
    end
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
