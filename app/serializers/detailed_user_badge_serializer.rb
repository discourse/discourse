# frozen_string_literal: true

class DetailedUserBadgeSerializer < BasicUserBadgeSerializer
  has_one :granted_by, serializer: UserBadgeSerializer::UserSerializer

  attributes :post_number, :topic_id, :topic_title, :is_favorite, :can_favorite

  def include_post_number?
    object.post
  end

  alias :include_topic_id? :include_post_number?
  alias :include_topic_title? :include_post_number?

  def post_number
    object.post.post_number if object.post
  end

  def topic_id
    object.post.topic_id if object.post
  end

  def topic_title
    object.post.topic.title if object.post && object.post.topic
  end

  def can_favorite
    SiteSetting.max_favorite_badges > 0 &&
    (scope.current_user.present? && object.user_id == scope.current_user.id) &&
    !(1..4).include?(object.badge_id)
  end
end
